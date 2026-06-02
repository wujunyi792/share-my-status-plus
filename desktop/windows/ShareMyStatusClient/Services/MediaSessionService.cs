using ShareMyStatusClient.Models.Domain;
using ShareMyStatusClient.Utilities;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Event-driven now-playing collector built on the Windows System Media Transport
/// Controls (GSMTC) API — the official, permission-free way to read what's playing
/// across Spotify, browsers, native players, etc. This is the Windows analogue of the
/// macOS MediaRemote adapter, but uses a supported public API.
/// </summary>
public sealed class MediaSessionService
{
    private readonly AppLogger _logger = AppLogger.Media;
    private readonly SemaphoreSlim _refreshLock = new(1, 1);
    private readonly object _gate = new();

    private GlobalSystemMediaTransportControlsSessionManager? _manager;
    private GlobalSystemMediaTransportControlsSession? _session;
    private Action<MusicSnapshot?>? _callback;
    private HashSet<string> _whitelist = new(StringComparer.OrdinalIgnoreCase);
    private string? _lastEmittedKey;
    private bool _running;

    public bool IsActive
    {
        get { lock (_gate) { return _running; } }
    }

    /// <summary>Enumerates the SourceAppUserModelId of every current media session
    /// (so the settings UI can offer them as whitelist candidates).</summary>
    public static async Task<List<string>> GetActiveSourceIdsAsync()
    {
        try
        {
            var manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
            var ids = new List<string>();
            foreach (var session in manager.GetSessions())
            {
                try
                {
                    var id = session.SourceAppUserModelId;
                    if (!string.IsNullOrEmpty(id))
                        ids.Add(id);
                }
                catch
                {
                    // ignore individual sessions we can't read
                }
            }
            return ids.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        }
        catch
        {
            return new List<string>();
        }
    }

    public void UpdateWhitelist(IEnumerable<string> ids)
    {
        lock (_gate)
        {
            _whitelist = new HashSet<string>(ids, StringComparer.OrdinalIgnoreCase);
        }
    }

    public async Task StartAsync(Action<MusicSnapshot?> callback)
    {
        lock (_gate)
        {
            if (_running) return;
        }

        try
        {
            _manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
        }
        catch (Exception ex)
        {
            _logger.Error("Failed to obtain media session manager", ex);
            return;
        }

        _manager.CurrentSessionChanged += OnCurrentSessionChanged;
        HookSession(_manager.GetCurrentSession());

        // Publish callback and running together so RefreshAsync (which snapshots both
        // under _gate) never sees a half-initialized state, and events arriving before
        // this point are dropped by the _running guard.
        lock (_gate)
        {
            _callback = callback;
            _running = true;
            _lastEmittedKey = null;
        }

        _logger.Info("Media session monitoring started");
        await RefreshAsync(forceEmit: true);
    }

    public Task StopAsync()
    {
        lock (_gate)
        {
            _running = false;
            _lastEmittedKey = null;
            _callback = null;
        }

        if (_manager != null)
            _manager.CurrentSessionChanged -= OnCurrentSessionChanged;
        UnhookSession();
        _manager = null;

        _logger.Info("Media session monitoring stopped");
        return Task.CompletedTask;
    }

    // ---- Session wiring ----

    private void HookSession(GlobalSystemMediaTransportControlsSession? session)
    {
        UnhookSession();
        lock (_gate)
        {
            _session = session;
        }
        if (session != null)
        {
            session.MediaPropertiesChanged += OnMediaPropertiesChanged;
            session.PlaybackInfoChanged += OnPlaybackInfoChanged;
        }
    }

    private void UnhookSession()
    {
        GlobalSystemMediaTransportControlsSession? session;
        lock (_gate)
        {
            session = _session;
            _session = null;
        }
        if (session != null)
        {
            session.MediaPropertiesChanged -= OnMediaPropertiesChanged;
            session.PlaybackInfoChanged -= OnPlaybackInfoChanged;
        }
    }

    private void OnCurrentSessionChanged(
        GlobalSystemMediaTransportControlsSessionManager sender,
        CurrentSessionChangedEventArgs args)
    {
        lock (_gate)
        {
            if (!_running)
                return; // ignore events arriving during/after Stop
        }
        HookSession(sender.GetCurrentSession());
        _ = RefreshAsync(forceEmit: false);
    }

    private void OnMediaPropertiesChanged(
        GlobalSystemMediaTransportControlsSession sender,
        MediaPropertiesChangedEventArgs args)
        => _ = RefreshAsync(forceEmit: false);

    private void OnPlaybackInfoChanged(
        GlobalSystemMediaTransportControlsSession sender,
        PlaybackInfoChangedEventArgs args)
        => _ = RefreshAsync(forceEmit: false);

    // ---- Snapshot building ----

    private async Task RefreshAsync(bool forceEmit)
    {
        bool running;
        lock (_gate) { running = _running; }
        if (!running && !forceEmit)
            return;

        await _refreshLock.WaitAsync().ConfigureAwait(false);
        try
        {
            GlobalSystemMediaTransportControlsSession? session;
            HashSet<string> whitelist;
            lock (_gate)
            {
                session = _session;
                whitelist = _whitelist;
            }

            var snapshot = session == null
                ? null
                : await BuildSnapshotAsync(session, whitelist).ConfigureAwait(false);

            var key = snapshot == null
                ? "<none>"
                : $"{snapshot.Title}|{snapshot.Artist}|{snapshot.IsPlaying}|{snapshot.ArtworkData?.Length ?? 0}";

            Action<MusicSnapshot?>? callback;
            lock (_gate)
            {
                // Re-check running inside the lock so a concurrent Stop suppresses late emits.
                if (!_running && !forceEmit)
                    return;
                if (!forceEmit && key == _lastEmittedKey)
                    return;
                _lastEmittedKey = key;
                callback = _callback;
            }

            callback?.Invoke(snapshot);
        }
        catch (Exception ex)
        {
            _logger.Error("Media refresh failed", ex);
        }
        finally
        {
            _refreshLock.Release();
        }
    }

    private async Task<MusicSnapshot?> BuildSnapshotAsync(
        GlobalSystemMediaTransportControlsSession session,
        HashSet<string> whitelist)
    {
        string? sourceId = null;
        try { sourceId = session.SourceAppUserModelId; } catch { /* ignore */ }

        // Empty whitelist = allow all (matches macOS semantics).
        if (whitelist.Count > 0 && (sourceId == null || !whitelist.Contains(sourceId)))
            return null;

        GlobalSystemMediaTransportControlsSessionMediaProperties props;
        try
        {
            props = await session.TryGetMediaPropertiesAsync();
        }
        catch (Exception ex)
        {
            _logger.Debug($"Media properties fetch failed: {ex.Message}");
            return null;
        }

        if (props == null)
            return null;

        var title = props.Title ?? string.Empty;
        var artist = props.Artist ?? string.Empty;
        // Require both title and artist, matching the macOS validity check.
        if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(artist))
            return null;

        var album = string.IsNullOrEmpty(props.AlbumTitle) ? "Unknown Album" : props.AlbumTitle;

        var isPlaying = false;
        try
        {
            var playback = session.GetPlaybackInfo();
            isPlaying = playback?.PlaybackStatus
                == GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing;
        }
        catch { /* ignore */ }

        var artwork = await ReadThumbnailAsync(props.Thumbnail).ConfigureAwait(false);

        return new MusicSnapshot(title, artist, album, isPlaying, sourceId, artwork, DateTimeOffset.Now);
    }

    private async Task<byte[]?> ReadThumbnailAsync(IRandomAccessStreamReference? reference)
    {
        if (reference == null)
            return null;

        try
        {
            using var stream = await reference.OpenReadAsync();
            if (stream == null || stream.Size == 0)
                return null;

            using var reader = new DataReader(stream);
            // LoadAsync returns the number of bytes actually buffered; reading more
            // than that throws, so size the buffer to the loaded length.
            var loaded = await reader.LoadAsync((uint)stream.Size);
            if (loaded == 0)
                return null;
            var bytes = new byte[loaded];
            reader.ReadBytes(bytes);
            return bytes;
        }
        catch (Exception ex)
        {
            _logger.Debug($"Thumbnail read failed: {ex.Message}");
            return null;
        }
    }
}
