using ShareMyStatusClient.Utilities;
using Velopack;
using Velopack.Sources;

namespace ShareMyStatusClient.Services;

/// <summary>
/// Silent auto-update on top of Velopack, pulling releases from GitHub Releases.
/// The Windows counterpart of the macOS Sparkle integration.
/// </summary>
public sealed class UpdateService
{
    private readonly AppLogger _logger = AppLogger.App;
    private readonly UpdateManager _manager;

    public UpdateService(string repoUrl)
    {
        // Stable channel, no prerelease, anonymous (public repo).
        _manager = new UpdateManager(new GithubSource(repoUrl, null, false));
    }

    /// <summary>True only when running as an installed Velopack app (false for a loose/dev exe).</summary>
    public bool IsInstalled => _manager.IsInstalled;

    public string? CurrentVersion => _manager.CurrentVersion?.ToString();

    /// <summary>Checks for an update. Returns null when up-to-date or not installed.</summary>
    public async Task<UpdateInfo?> CheckAsync()
    {
        if (!_manager.IsInstalled)
            return null;
        try
        {
            return await _manager.CheckForUpdatesAsync().ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.Error("Update check failed", ex);
            return null;
        }
    }

    /// <summary>Downloads the update and relaunches into the new version (process exits).</summary>
    public async Task DownloadAndRestartAsync(UpdateInfo info)
    {
        await _manager.DownloadUpdatesAsync(info).ConfigureAwait(false);
        _manager.ApplyUpdatesAndRestart(info);
    }
}
