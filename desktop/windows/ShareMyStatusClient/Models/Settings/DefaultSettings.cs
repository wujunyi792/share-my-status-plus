using ShareMyStatusClient.Models.Domain;

namespace ShareMyStatusClient.Models.Settings;

/// <summary>
/// Centralized default settings, the Windows counterpart of the macOS DefaultSettings.
/// Apps are identified by process executable name (activity) or by the media session's
/// SourceAppUserModelId (music) — both compared case-insensitively.
/// </summary>
public static class DefaultSettings
{
    // ---- Network ----

    /// <summary>Full report endpoint. The user must point this at their server.</summary>
    public const string EndpointUrl = "https://your-server.example.com/api/v1/state/report";

    public const string SecretKey = "";

    // ---- Feature toggles ----

    public const bool MusicReportingEnabled = true;
    public const bool SystemReportingEnabled = true;
    public const bool ActivityReportingEnabled = true;

    // ---- Polling intervals (seconds) ----

    public const double SystemPollingInterval = 10.0;
    public const double ActivityPollingInterval = 5.0;

    public const double MinPollingInterval = 5.0;
    public const double MaxPollingInterval = 300.0;
    public const double PollingIntervalStep = 5.0;

    /// <summary>Idle threshold in seconds (5 minutes), matching macOS.</summary>
    public const double IdleTimeThreshold = 300.0;

    /// <summary>Tag used when no enabled activity group matches the foreground app.</summary>
    public const string DefaultActivityTag = "其他";

    // ---- Music app whitelist (SourceAppUserModelId / exe name) ----
    // An empty whitelist means "allow all sources" (same semantics as macOS).

    public static List<string> MusicAppWhitelist() => new()
    {
        "Spotify.exe",
        "cloudmusic.exe",      // 网易云音乐
        "QQMusic.exe",         // QQ 音乐
        "kugou.exe",           // 酷狗
        "foobar2000.exe",
        "AppleInc.AppleMusicWin_nzyj5cx40ttqa!App", // Apple Music (Store)
        "Microsoft.ZuneMusic_8wekyb3d8bbwe!Microsoft.ZuneMusic", // Media Player / Groove
        "msedge.exe",
        "chrome.exe",
    };

    // ---- Activity groups (process exe names, lower-cased) ----
    // Order matters: the first enabled group containing the process wins.

    public static List<ActivityGroup> ActivityGroups() => new()
    {
        new ActivityGroup("在工作&研究", new[]
        {
            "winword.exe", "excel.exe", "powerpnt.exe", "onenote.exe", "outlook.exe",
            "ms-teams.exe", "teams.exe", "feishu.exe", "lark.exe", "corplink.exe",
            "notion.exe", "obsidian.exe", "onedrive.exe", "wps.exe", "et.exe", "wpp.exe",
        }),
        new ActivityGroup("在搞研发", new[]
        {
            "code.exe", "cursor.exe", "trae.exe", "devenv.exe", "rider64.exe",
            "idea64.exe", "goland64.exe", "pycharm64.exe", "webstorm64.exe", "clion64.exe",
            "datagrip64.exe", "sublime_text.exe", "010editor.exe", "postman.exe",
            "another redis desktop manager.exe", "apifox.exe", "compass.exe",
            "podman desktop.exe", "docker desktop.exe", "windowsterminal.exe",
        }),
        new ActivityGroup("在设计", new[]
        {
            "photoshop.exe", "figma.exe", "illustrator.exe", "xd.exe", "afdesign.exe",
            "afphoto.exe", "blender.exe",
        }),
        new ActivityGroup("在开会", new[]
        {
            "zoom.exe", "slack.exe", "webex.exe", "voov.exe", "wemeetapp.exe",
        }),
        new ActivityGroup("在浏览", new[]
        {
            "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe",
            "vivaldi.exe", "arc.exe",
        }),
        new ActivityGroup("在终端", new[]
        {
            "windowsterminal.exe", "powershell.exe", "pwsh.exe", "cmd.exe",
            "mintty.exe", "alacritty.exe", "wezterm-gui.exe", "conemu64.exe",
        }),
        new ActivityGroup("在娱乐", new[]
        {
            "spotify.exe", "cloudmusic.exe", "qqmusic.exe", "kugou.exe",
            "bilibili.exe", "douyin.exe", "potplayermini64.exe", "vlc.exe",
            "applemusic.exe",
        }),
        new ActivityGroup("在社交", new[]
        {
            "qq.exe", "telegram.exe", "discord.exe", "whatsapp.exe", "weixin.exe",
            "wechat.exe", "tim.exe",
        }),
    };
}
