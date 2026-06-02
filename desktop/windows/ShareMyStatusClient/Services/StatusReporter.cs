using ShareMyStatusClient.Models.Api;
using ShareMyStatusClient.Models.Domain;
using ShareMyStatusClient.Models.Settings;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Coordinates the collection services and reports to the backend. Mirrors the macOS
/// StatusReporter: system + activity are polled on dedicated loops, music is event-driven.
/// </summary>
public sealed class StatusReporter
{
    private readonly SystemMonitorService _system = new();
    private readonly ActivityDetectorService _activity = new();
    private readonly MediaSessionService _media = new();
    private readonly NetworkService _network = new();
    private readonly CoverService _cover = new();
    private readonly AppLogger _logger = AppLogger.Reporter;

    private readonly object _stateGate = new();
    private AppConfiguration _config = new();

    private CancellationTokenSource? _systemCts;
    private CancellationTokenSource? _activityCts;
    private string? _lastReportedActivityLabel;

    public bool IsReporting { get; private set; }
    public string ReportingStatus { get; private set; } = "未启动";
    public Exception? LastError { get; private set; }

    public MusicSnapshot? CurrentMusic { get; private set; }
    public SystemSnapshot? CurrentSystem { get; private set; }
    public ActivitySnapshot? CurrentActivity { get; private set; }

    public DateTimeOffset? LastReportTime => _network.LastReportTime;
    public int ReportCount => _network.ReportCount;

    /// <summary>Raised whenever observable state changes (status, current snapshots).</summary>
    public event EventHandler? Changed;

    // ---- Configuration ----

    public void ApplyConfiguration(AppConfiguration config)
    {
        var clone = config.Clone();
        lock (_stateGate)
        {
            _config = clone;
        }

        _network.UpdateConfiguration(clone.EndpointUrl, clone.SecretKey);
        _cover.UpdateConfiguration(clone.EndpointUrl, clone.SecretKey);
        _media.UpdateWhitelist(clone.MusicAppWhitelist);

        _logger.Info("Configuration applied");

        if (IsReporting)
        {
            // Restart loops to pick up new toggles/intervals (simple and race-free).
            _ = RestartAsync();
        }
    }

    private async Task RestartAsync()
    {
        await StopAsync().ConfigureAwait(false);
        await StartAsync().ConfigureAwait(false);
    }

    // ---- Lifecycle ----

    public async Task StartAsync()
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

    public async Task StopAsync()
    {
        _logger.Info("Stopping status reporting...");
        IsReporting = false;

        _systemCts?.Cancel();
        _systemCts = null;
        _activityCts?.Cancel();
        _activityCts = null;

        await _media.StopAsync().ConfigureAwait(false);

        lock (_stateGate)
        {
            CurrentMusic = null;
            CurrentSystem = null;
            CurrentActivity = null;
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

        _ = Task.Run(async () =>
        {
            while (!cts.IsCancellationRequested)
            {
                try
                {
                    var snapshot = _system.Collect();
                    lock (_stateGate) { CurrentSystem = snapshot; }
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

        _ = Task.Run(async () =>
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
                        lock (_stateGate) { CurrentActivity = snapshot; }
                        RaiseChanged();

                        bool changed;
                        lock (_stateGate)
                        {
                            changed = _lastReportedActivityLabel != snapshot.ActivityTag;
                            if (changed) _lastReportedActivityLabel = snapshot.ActivityTag;
                        }

                        if (changed)
                            await SendReportAsync(ReportEvent.ForActivity(snapshot.ToActivityInfo()), "activity", cts.Token)
                                .ConfigureAwait(false);
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
        bool artworkOnly;
        lock (_stateGate)
        {
            var current = CurrentMusic;
            // Same song (title+artist) => treat as artwork/state-only update; update local
            // state but don't fire a separate report (matches macOS behaviour).
            artworkOnly = music != null && current != null
                && music.Title == current.Title
                && music.Artist == current.Artist;
            CurrentMusic = music;
        }

        RaiseChanged();

        if (artworkOnly)
            return;

        await ReportMusicChangeAsync().ConfigureAwait(false);
    }

    private async Task ReportMusicChangeAsync()
    {
        MusicSnapshot? current;
        lock (_stateGate) { current = CurrentMusic; }

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

    private async Task SendReportAsync(ReportEvent ev, string source, CancellationToken ct)
    {
        var request = new BatchReportRequest();
        request.Events.Add(ev);

        try
        {
            var response = await _network.ReportStatusAsync(request, ct).ConfigureAwait(false);
            LastError = null;
            _logger.Info($"[{source}] report sent: accepted={response.Accepted ?? 0}");
        }
        catch (OperationCanceledException)
        {
            // Shutting down; ignore.
        }
        catch (Exception ex)
        {
            LastError = ex;
            _logger.Error($"[{source}] report failed", ex);
        }

        UpdateStatus();
    }

    // ---- Status ----

    private void UpdateStatus()
    {
        string status;
        AppConfiguration cfg;
        lock (_stateGate) { cfg = _config; }

        if (!IsReporting)
        {
            status = "未启动";
        }
        else if (!NetworkService.IsConnected)
        {
            status = "网络未连接";
        }
        else if (LastError != null)
        {
            status = $"错误: {LastError.Message}";
        }
        else
        {
            var modules = new List<string>();
            if (cfg.MusicReportingEnabled) modules.Add("音乐");
            if (cfg.SystemReportingEnabled) modules.Add("系统");
            if (cfg.ActivityReportingEnabled) modules.Add("活动");
            status = modules.Count == 0 ? "无活动模块" : "正在上报: " + string.Join(", ", modules);
        }

        SetStatus(status);
    }

    private void SetStatus(string status)
    {
        ReportingStatus = status;
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
            music = CurrentMusic;
            system = CurrentSystem;
            activity = CurrentActivity;
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
}
