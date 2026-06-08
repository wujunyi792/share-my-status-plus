using ShareMyStatusClient.Models.Api;
using ShareMyStatusClient.Models.Settings;

namespace ShareMyStatusClient.Models.Domain;

// Domain snapshots produced by the collection services, with conversions to
// the wire models. These mirror the macOS Domain models.

/// <summary>System metrics snapshot. All percentages are 0..1; null = unavailable.</summary>
public sealed record SystemSnapshot(
    double? BatteryLevel,
    bool? IsCharging,
    double? CpuUsage,
    double? MemoryUsage,
    DateTimeOffset Timestamp)
{
    public SystemInfo ToSystemInfo() => new()
    {
        BatteryPct = BatteryLevel,
        Charging = IsCharging,
        CpuPct = CpuUsage,
        MemoryPct = MemoryUsage,
        Ts = Timestamp.ToUnixTimeMilliseconds(),
    };

    public int? BatteryPercentage => BatteryLevel is { } v ? (int)(v * 100) : null;
    public int? CpuPercentage => CpuUsage is { } v ? (int)(v * 100) : null;
    public int? MemoryPercentage => MemoryUsage is { } v ? (int)(v * 100) : null;
}

/// <summary>Now-playing snapshot from the Windows media session.</summary>
public sealed record MusicSnapshot(
    string Title,
    string Artist,
    string Album,
    bool IsPlaying,
    string? SourceAppId,
    byte[]? ArtworkData,
    DateTimeOffset Timestamp)
{
    public MusicInfo ToMusicInfo(string? coverHash = null) => new()
    {
        Title = Title,
        Artist = Artist,
        Album = Album,
        CoverHash = coverHash,
        Ts = Timestamp.ToUnixTimeMilliseconds(),
    };
}

/// <summary>Foreground-activity snapshot. On Windows the app is identified by its
/// process executable name (e.g. "code.exe"), the analogue of macOS bundle ids.</summary>
public sealed record ActivitySnapshot(
    string ActiveApplication,
    string? ProcessName,
    double IdleTimeSeconds,
    string ActivityTag,
    DateTimeOffset Timestamp)
{
    public ActivityInfo ToActivityInfo() => new()
    {
        Label = ActivityTag,
        Ts = Timestamp.ToUnixTimeMilliseconds(),
    };

    public bool IsIdle => IdleTimeSeconds > DefaultSettings.IdleTimeThreshold;
}

/// <summary>A user-defined activity group: a label plus the process names that map to it.</summary>
public sealed class ActivityGroup
{
    public string Name { get; set; } = string.Empty;

    /// <summary>Windows process executable names, lower-cased (e.g. "chrome.exe").</summary>
    public List<string> ProcessNames { get; set; } = new();

    public bool IsEnabled { get; set; } = true;

    public ActivityGroup()
    {
    }

    public ActivityGroup(string name, IEnumerable<string> processNames, bool isEnabled = true)
    {
        Name = name;
        ProcessNames = processNames.Select(p => p.ToLowerInvariant()).ToList();
        IsEnabled = isEnabled;
    }

    public ActivityGroup Clone() => new()
    {
        Name = Name,
        ProcessNames = new List<string>(ProcessNames),
        IsEnabled = IsEnabled,
    };
}
