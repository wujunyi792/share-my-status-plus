using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using ShareMyStatusClient.Models.Domain;

namespace ShareMyStatusClient.Models.Settings;

/// <summary>
/// Application configuration persisted to %APPDATA%\ShareMyStatus\config.json.
/// The Windows counterpart of the macOS AppConfiguration (which used UserDefaults).
/// </summary>
public sealed class AppConfiguration
{
    public string SecretKey { get; set; } = DefaultSettings.SecretKey;
    public string EndpointUrl { get; set; } = DefaultSettings.EndpointUrl;

    public bool MusicReportingEnabled { get; set; } = DefaultSettings.MusicReportingEnabled;
    public bool SystemReportingEnabled { get; set; } = DefaultSettings.SystemReportingEnabled;
    public bool ActivityReportingEnabled { get; set; } = DefaultSettings.ActivityReportingEnabled;

    public List<string> MusicAppWhitelist { get; set; } = DefaultSettings.MusicAppWhitelist();
    public List<ActivityGroup> ActivityGroups { get; set; } = DefaultSettings.ActivityGroups();

    public double SystemPollingInterval { get; set; } = DefaultSettings.SystemPollingInterval;
    public double ActivityPollingInterval { get; set; } = DefaultSettings.ActivityPollingInterval;

    /// <summary>Whether reporting was active when the app last closed (auto-resume on launch).</summary>
    public bool ReporterEnabled { get; set; }

    /// <summary>Whether the app should launch at Windows sign-in.</summary>
    public bool LaunchAtLogin { get; set; }

    // ---- Persistence ----

    private static readonly JsonSerializerOptions FileJson = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never,
    };

    public static string ConfigDirectory =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ShareMyStatus");

    public static string ConfigPath => Path.Combine(ConfigDirectory, "config.json");

    public static AppConfiguration Load()
    {
        try
        {
            if (File.Exists(ConfigPath))
            {
                var json = File.ReadAllText(ConfigPath);
                var config = JsonSerializer.Deserialize<AppConfiguration>(json, FileJson);
                if (config != null)
                {
                    config.Normalize();
                    return config;
                }
            }
        }
        catch
        {
            // Fall through to defaults on any read/parse failure.
        }

        return new AppConfiguration();
    }

    public void Save()
    {
        Directory.CreateDirectory(ConfigDirectory);
        var json = JsonSerializer.Serialize(this, FileJson);
        // Atomic write: write to temp then rename over the target (atomic on the same volume).
        var tmp = ConfigPath + ".tmp";
        File.WriteAllText(tmp, json);
        File.Move(tmp, ConfigPath, overwrite: true);
    }

    private void Normalize()
    {
        MusicAppWhitelist ??= new List<string>();
        ActivityGroups ??= new List<ActivityGroup>();
        foreach (var g in ActivityGroups)
        {
            g.ProcessNames = (g.ProcessNames ?? new List<string>())
                .Select(p => p.Trim().ToLowerInvariant())
                .Where(p => p.Length > 0)
                .ToList();
        }

        SystemPollingInterval = Math.Clamp(SystemPollingInterval, DefaultSettings.MinPollingInterval, DefaultSettings.MaxPollingInterval);
        ActivityPollingInterval = Math.Clamp(ActivityPollingInterval, DefaultSettings.MinPollingInterval, DefaultSettings.MaxPollingInterval);
    }

    public bool IsValid() =>
        !string.IsNullOrWhiteSpace(SecretKey) &&
        Uri.TryCreate(EndpointUrl, UriKind.Absolute, out _);

    public AppConfiguration Clone() => new()
    {
        SecretKey = SecretKey,
        EndpointUrl = EndpointUrl,
        MusicReportingEnabled = MusicReportingEnabled,
        SystemReportingEnabled = SystemReportingEnabled,
        ActivityReportingEnabled = ActivityReportingEnabled,
        MusicAppWhitelist = new List<string>(MusicAppWhitelist),
        ActivityGroups = ActivityGroups.Select(g => g.Clone()).ToList(),
        SystemPollingInterval = SystemPollingInterval,
        ActivityPollingInterval = ActivityPollingInterval,
        ReporterEnabled = ReporterEnabled,
        LaunchAtLogin = LaunchAtLogin,
    };

    /// <summary>Copy editable fields from another instance (used when applying the settings dialog).</summary>
    public void CopyFrom(AppConfiguration other)
    {
        SecretKey = other.SecretKey;
        EndpointUrl = other.EndpointUrl;
        MusicReportingEnabled = other.MusicReportingEnabled;
        SystemReportingEnabled = other.SystemReportingEnabled;
        ActivityReportingEnabled = other.ActivityReportingEnabled;
        MusicAppWhitelist = new List<string>(other.MusicAppWhitelist);
        ActivityGroups = other.ActivityGroups.Select(g => g.Clone()).ToList();
        SystemPollingInterval = other.SystemPollingInterval;
        ActivityPollingInterval = other.ActivityPollingInterval;
        LaunchAtLogin = other.LaunchAtLogin;
    }

    public void ResetToDefaults()
    {
        SecretKey = DefaultSettings.SecretKey;
        EndpointUrl = DefaultSettings.EndpointUrl;
        MusicReportingEnabled = DefaultSettings.MusicReportingEnabled;
        SystemReportingEnabled = DefaultSettings.SystemReportingEnabled;
        ActivityReportingEnabled = DefaultSettings.ActivityReportingEnabled;
        MusicAppWhitelist = DefaultSettings.MusicAppWhitelist();
        ActivityGroups = DefaultSettings.ActivityGroups();
        SystemPollingInterval = DefaultSettings.SystemPollingInterval;
        ActivityPollingInterval = DefaultSettings.ActivityPollingInterval;
    }

    // ---- Import / Export ----

    /// <summary>Serialize to a shareable JSON string. Secret key is optional.</summary>
    public string ExportToJson(bool includeSecretKey = false)
    {
        var export = new ExportableConfiguration
        {
            SecretKey = includeSecretKey ? SecretKey : null,
            EndpointUrl = EndpointUrl,
            MusicReportingEnabled = MusicReportingEnabled,
            SystemReportingEnabled = SystemReportingEnabled,
            ActivityReportingEnabled = ActivityReportingEnabled,
            MusicAppWhitelist = new List<string>(MusicAppWhitelist),
            ActivityGroups = ActivityGroups.Select(g => g.Clone()).ToList(),
            SystemPollingInterval = SystemPollingInterval,
            ActivityPollingInterval = ActivityPollingInterval,
            ExportDate = DateTimeOffset.UtcNow.ToString("o"),
            Version = "1.0",
        };
        return JsonSerializer.Serialize(export, FileJson);
    }

    /// <summary>Apply a previously exported JSON config. Returns an error message, or null on success.</summary>
    public string? ImportFromJson(string json)
    {
        ExportableConfiguration? cfg;
        try
        {
            cfg = JsonSerializer.Deserialize<ExportableConfiguration>(json, FileJson);
        }
        catch
        {
            return "JSON 格式错误，请检查配置内容";
        }

        if (cfg == null)
            return "JSON 格式错误，请检查配置内容";
        if (string.IsNullOrWhiteSpace(cfg.EndpointUrl))
            return "服务器地址不能为空";
        if (!Uri.TryCreate(cfg.EndpointUrl, UriKind.Absolute, out _))
            return "服务器地址格式无效";

        if (!string.IsNullOrEmpty(cfg.SecretKey))
            SecretKey = cfg.SecretKey!;
        EndpointUrl = cfg.EndpointUrl;
        MusicReportingEnabled = cfg.MusicReportingEnabled;
        SystemReportingEnabled = cfg.SystemReportingEnabled;
        ActivityReportingEnabled = cfg.ActivityReportingEnabled;
        MusicAppWhitelist = cfg.MusicAppWhitelist ?? new List<string>();
        ActivityGroups = (cfg.ActivityGroups ?? new List<ActivityGroup>()).Select(g => g.Clone()).ToList();
        SystemPollingInterval = cfg.SystemPollingInterval;
        ActivityPollingInterval = cfg.ActivityPollingInterval;
        Normalize();
        return null;
    }
}

/// <summary>Portable subset of <see cref="AppConfiguration"/> for import/export.</summary>
public sealed class ExportableConfiguration
{
    public string? SecretKey { get; set; }
    public string EndpointUrl { get; set; } = string.Empty;
    public bool MusicReportingEnabled { get; set; }
    public bool SystemReportingEnabled { get; set; }
    public bool ActivityReportingEnabled { get; set; }
    public List<string>? MusicAppWhitelist { get; set; }
    public List<ActivityGroup>? ActivityGroups { get; set; }
    public double SystemPollingInterval { get; set; }
    public double ActivityPollingInterval { get; set; }
    public string ExportDate { get; set; } = string.Empty;
    public string Version { get; set; } = "1.0";
}
