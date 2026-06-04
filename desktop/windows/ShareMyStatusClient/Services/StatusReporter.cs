using ShareMyStatusClient.Models.Api;
using ShareMyStatusClient.Models.Domain;
using ShareMyStatusClient.Models.Settings;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Coordinates the collection services and reports to the backend. Mirrors the macOS
/// StatusReporter: system + activity are polled on dedicated loops, music is event-driven.
/// </summary>
public sealed class StatusReporter : IDisposable
{
    private readonly SystemMonitorService _system = new();
    private readonly ActivityDetectorService _activity = new();
    private readonly MediaSessionService _media = new();
    private readonly NetworkService _network = new();
    private readonly CoverService _cover = new();
    private readonly AppLogger _logger = AppLogger.Reporter;

    private readonly object _stateGate = new();
    // Serializes Start/Stop/Restart so configuration changes can't interleave loops.
    private readonly SemaphoreSlim _lifecycleLock = new(1, 1);
    // Serializes event-driven music handling so concurrent GSMTC callbacks can't
    // reorder or double-report.
    private readonly SemaphoreSlim _musicLock = new(1, 1);

    private AppConfiguration _config = new();

    private CancellationTokenSource? _systemCts;
    private CancellationTokenSource? _activityCts;
    private Task? _systemTask;
    private Task? _activityTask;
    private string? _lastReportedActivityLabel;

    // Backing fields for cross-thread-observed state (guarded by _stateGate).
    private bool _isReporting;
    private string _reportingStatus = "未启动";
    private Exception? _lastError;

    private MusicSnapshot? _currentMusic;
    private SystemSnapshot? _currentSystem;
    private ActivitySnapshot? _currentActivity;
    private ClientResources? _clientResources;

    public bool IsReporting
    {
        get { lock (_stateGate) { return _isReporting; } }
        private set { lock (_stateGate) { _isReporting = value; } }
    }

    public string ReportingStatus
    {
        get { lock (_stateGate) { return _reportingStatus; } }
    }

    public Exception? LastError
    {
        get { lock (_stateGate) { return _lastError; } }
        private set { lock (_stateGate) { _lastError = value; } }
    }

    public MusicSnapshot? CurrentMusic
    {
        get { lock (_stateGate) { return _currentMusic; } }
    }

    public SystemSnapshot? CurrentSystem
    {
        get { lock (_stateGate) { return _currentSystem; } }
    }

    public ActivitySnapshot? CurrentActivity
    {
        get { lock (_stateGate) { return _currentActivity; } }
    }

    /// <summary>Server-provided resource links (user status page / signature DIY), if fetched.</summary>
    public ClientResources? ClientResources
    {
        get { lock (_stateGate) { return _clientResources; } }
        private set { lock (_stateGate) { _clientResources = value; } }
    }

    /// <summary>Raised whenever observable state changes (status, current snapshots).</summary>
    public event EventHandler? Changed;

    // ---- Configuration ----

    public void ApplyConfiguration(AppConfiguration config)
    {
        var clone = config.Clone();
        lock (_stateGate) { _config = clone; }

        _network.UpdateConfiguration(clone.EndpointUrl, clone.SecretKey);
        _cover.UpdateConfiguration(clone.EndpointUrl, clone.SecretKey);
        _media.UpdateWhitelist(clone.MusicAppWhitelist);

        _logger.Info("Configuration applied");

        // Refresh server resource links in the background (best-effort).
        _ = RefreshClientResourcesAsync();

        if (IsReporting)
        {
            // Restart loops to pick up new toggles/intervals (serialized + race-free).
            _ = RestartAsync();
        }
    }

    /// <summary>Validate the given endpoint + secret against the server (used by the settings dialog).</summary>
    public Task<(bool Ok, string Message)> TestConnectionAsync(string endpointUrl, string secretKey) =>
        _network.TestConnectionAsync(endpointUrl, secretKey, CancellationToken.None);

    public async Task RefreshClientResourcesAsync()
    {
        try
        {
            var resources = await _network.FetchClientResourcesAsync(CancellationToken.None).ConfigureAwait(false);
            if (resources != null)
            {
                ClientResources = resources;
                RaiseChanged();
            }
        }
        catch (Exception ex)
        {
            _logger.Debug($"Client resources fetch failed: {ex.Message}");
        }
    }

    // ---- Lifecycle (serialized through _lifecycleLock) ----

    public async Task StartAsync()
    {
        await _lifecycleLock.WaitAsync().ConfigureAwait(false);
        try { await StartCoreAsync().ConfigureAwait(false); }
        finally { _lifecycleLock.Release(); }
    }

    public async Task StopAsync()
    {
        await _lifecycleLock.WaitAsync().ConfigureAwait(false);
        try { await StopCoreAsync().ConfigureAwait(false); }
        finally { _lifecycleLock.Release(); }
    }

    private async Task RestartAsync()
    {
        await _lifecycleLock.WaitAsync().ConfigureAwait(false);
        try
        {
            await StopCoreAsync().ConfigureAwait(false);
            await StartCoreAsync().ConfigureAwait(false);
        }
        finally { _lifecycleLock.Release(); }
    }

    private async Task StartCoreAsync()
    {
        AppConfiguration cfg;
        lock (_stateGate) { cfg = _config; }

        if (!cfg.IsValid())
        {
            _logger.Error("Invalid configuration; cannot start");
            SetStatus("配置不完整");
            return;
        }

        _logger.Info("Starting status reporting...");
        IsReporting = true;
        LastError = null;

        if (cfg.MusicReportingEnabled)
            await _media.StartAsync(OnMusicChanged).ConfigureAwait(false);

        if (cfg.SystemReportingEnabled)
            StartSystemLoop(cfg);

        if (cfg.ActivityReportingEnabled)
            StartActivityLoop(cfg);

        UpdateStatus();
    }

    private async Task StopCoreAsync()
    {
        _logger.Info("Stopping status reporting...");
        IsReporting = false;

        _systemCts?.Cancel();
        _activityCts?.Cancel();

        // Wait for the loops to actually exit before disposing their token sources.
        var pending = new[] { _systemTask, _activityTask }.Where(t => t != null).Cast<Task>().ToArray();
        if (pending.Length > 0)
        {
            try { await Task.WhenAll(pending).ConfigureAwait(false); }
            catch (OperationCanceledException) { /* expected */ }
            catch (Exception ex) { _logger.Debug($"Loop drain error: {ex.Message}"); }
        }

        _systemCts?.Dispose();
        _systemCts = null;
        _systemTask = null;
        _activityCts?.Dispose();
        _activityCts = null;
        _activityTask = null;

        await _media.StopAsync().ConfigureAwait(false);

        lock (_stateGate)
        {
            _currentMusic = null;
            _currentSystem = null;
            _currentActivity = null;
            _lastReportedActivityLabel = null;
        }

        UpdateStatus();
    }

    // ---- System loop ----

    private void StartSystemLoop(AppConfiguration cfg)
    {
        _system.Reset();
        var cts = new CancellationTokenSource();
        _systemCts = cts;
        var interval = TimeSpan.FromSeconds(cfg.SystemPollingInterval);

        _systemTask = Task.Run(async () =>
        {
            while (!cts.IsCancellationRequested)
            {
                try
                {
                    var snapshot = _system.Collect();
                    lock (_stateGate) { _currentSystem = snapshot; }
                    RaiseChanged();
                    await SendReportAsync(ReportEvent.ForSystem(snapshot.ToSystemInfo()), "system", cts.Token)
                        .ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    _logger.Error("System loop error", ex);
                }

                try { await Task.Delay(interval, cts.Token).ConfigureAwait(false); }
                catch (TaskCanceledException) { break; }
            }
        }, cts.Token);
    }

    // ---- Activity loop ----

    private void StartActivityLoop(AppConfiguration cfg)
    {
        var cts = new CancellationTokenSource();
        _activityCts = cts;
        var interval = TimeSpan.FromSeconds(cfg.ActivityPollingInterval);

        _activityTask = Task.Run(async () =>
        {
            while (!cts.IsCancellationRequested)
            {
                try
                {
                    List<ActivityGroup> groups;
                    lock (_stateGate) { groups = _config.ActivityGroups; }

                    var snapshot = _activity.Collect(groups);
                    if (snapshot != null)
                    {
                        string? lastLabel;
                        lock (_stateGate)
                        {
                            _currentActivity = snapshot;
                            lastLabel = _lastReportedActivityLabel;
                        }
                        RaiseChanged();

                        if (lastLabel != snapshot.ActivityTag)
                        {
                            // Only mark the label as reported after a successful send, so a
                            // failed report doesn't permanently suppress re-reporting it.
                            var ok = await SendReportAsync(ReportEvent.ForActivity(snapshot.ToActivityInfo()), "activity", cts.Token)
                                .ConfigureAwait(false);
                            if (ok)
                                lock (_stateGate) { _lastReportedActivityLabel = snapshot.ActivityTag; }
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.Error("Activity loop error", ex);
                }

                try { await Task.Delay(interval, cts.Token).ConfigureAwait(false); }
                catch (TaskCanceledException) { break; }
            }
        }, cts.Token);
    }

    // ---- Music (event-driven) ----

    private void OnMusicChanged(MusicSnapshot? music)
    {
        _ = HandleMusicAsync(music);
    }

    private async Task HandleMusicAsync(MusicSnapshot? music)
    {
        if (!IsReporting)
            return; // ignore late callbacks after stop

        // Serialize concurrent GSMTC callbacks so reports can't reorder or duplicate.
        await _musicLock.WaitAsync().ConfigureAwait(false);
        try
        {
            if (!IsReporting)
                return;

            bool artworkOnly;
            lock (_stateGate)
            {
                var current = _currentMusic;
                var sameSong = music != null && current != null
                    && music.Title == current.Title
                    && music.Artist == current.Artist;
                // GSMTC often delivers the thumbnail in a later event than the metadata.
                // If the cover only just arrived for the same song, still report it once so
                // the cover isn't lost (the macOS client coordinates this via waitingForArtwork).
                var artworkNewlyArrived = sameSong
                    && (current!.ArtworkData == null || current.ArtworkData.Length == 0)
                    && music!.ArtworkData is { Length: > 0 };
                artworkOnly = sameSong && !artworkNewlyArrived;
                _currentMusic = music;
            }

            RaiseChanged();

            if (!artworkOnly)
                await ReportMusicChangeAsync().ConfigureAwait(false);
        }
        finally
        {
            _musicLock.Release();
        }
    }

    private async Task ReportMusicChangeAsync()
    {
        if (!IsReporting)
            return;

        MusicSnapshot? current;
        lock (_stateGate) { current = _currentMusic; }

        // No current music (e.g. playback stopped) => nothing to report, matching macOS.
        if (current == null)
            return;

        string? coverHash = null;
        if (current.ArtworkData is { Length: > 0 } artwork)
        {
            try
            {
                coverHash = await _cover.CheckAndUploadCoverAsync(artwork, CancellationToken.None).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.Error("Failed to upload cover", ex);
            }
        }

        var info = current.ToMusicInfo(coverHash);
        await SendReportAsync(ReportEvent.ForMusic(info), "music", CancellationToken.None).ConfigureAwait(false);
    }

    // ---- Reporting ----

    private async Task<bool> SendReportAsync(ReportEvent ev, string source, CancellationToken ct)
    {
        var request = new BatchReportRequest();
        request.Events.Add(ev);

        var ok = false;
        try
        {
            var response = await _network.ReportStatusAsync(request, ct).ConfigureAwait(false);
            LastError = null;
            ok = true;
            _logger.Info($"[{source}] report sent: accepted={response.Accepted ?? 0}");
        }
        catch (OperationCanceledException)
        {
            return false; // shutting down; don't touch status
        }
        catch (Exception ex)
        {
            LastError = ex;
            _logger.Error($"[{source}] report failed", ex);
        }

        UpdateStatus();
        return ok;
    }

    // ---- Status ----

    private void UpdateStatus()
    {
        string status;
        AppConfiguration cfg;
        bool reporting;
        Exception? error;
        lock (_stateGate)
        {
            cfg = _config;
            reporting = _isReporting;
            error = _lastError;
        }

        if (!reporting)
        {
            status = "未启动";
        }
        else if (!NetworkService.IsConnected)
        {
            status = "网络未连接";
        }
        else if (error != null)
        {
            status = $"错误: {error.Message}";
        }
        else
        {
            var modules = new List<string>();
            // For music, reflect whether the media listener actually started (matches macOS).
            if (cfg.MusicReportingEnabled && _media.IsActive) modules.Add("音乐");
            if (cfg.SystemReportingEnabled) modules.Add("系统");
            if (cfg.ActivityReportingEnabled) modules.Add("活动");
            status = modules.Count == 0 ? "无活动模块" : "正在上报: " + string.Join(", ", modules);
        }

        SetStatus(status);
    }

    private void SetStatus(string status)
    {
        lock (_stateGate) { _reportingStatus = status; }
        RaiseChanged();
    }

    private void RaiseChanged() => Changed?.Invoke(this, EventArgs.Empty);

    /// <summary>Human-readable one-shot summary for the tray tooltip.</summary>
    public string GetStatusSummary()
    {
        var parts = new List<string>();

        MusicSnapshot? music;
        SystemSnapshot? system;
        ActivitySnapshot? activity;
        lock (_stateGate)
        {
            music = _currentMusic;
            system = _currentSystem;
            activity = _currentActivity;
        }

        if (music != null)
            parts.Add($"🎵 {music.Artist} - {music.Title}");

        if (system != null)
        {
            var sys = new List<string>();
            if (system.BatteryPercentage is { } b)
                sys.Add($"{(system.IsCharging == true ? "🔌" : "🔋")} {b}%");
            if (system.CpuPercentage is { } c)
                sys.Add($"💻 CPU {c}%");
            if (system.MemoryPercentage is { } m)
                sys.Add($"🧠 内存 {m}%");
            if (sys.Count > 0)
                parts.Add(string.Join(" ", sys));
        }

        if (activity != null)
            parts.Add($"{(activity.IsIdle ? "😴" : "👤")} {activity.ActivityTag}: {activity.ActiveApplication}");

        return parts.Count == 0 ? "无状态数据" : string.Join("\n", parts);
    }

    /// <summary>Releases owned services and synchronization primitives.
    /// Caller must have stopped reporting first (App does this on exit).</summary>
    public void Dispose()
    {
        _network.Dispose();
        _cover.Dispose();
        _media.Dispose();
        _lifecycleLock.Dispose();
        _musicLock.Dispose();
    }
}
