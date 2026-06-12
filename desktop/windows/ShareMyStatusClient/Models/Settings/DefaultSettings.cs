using ShareMyStatusClient.Models.Domain;

namespace ShareMyStatusClient.Models.Settings;

/// <summary>
/// Centralized default settings, the Windows counterpart of the macOS DefaultSettings.
/// Apps are identified by process executable name (activity) or by the media session's
/// SourceAppUserModelId (music) — both compared case-insensitively.
/// </summary>
public static class DefaultSettings
{
    /// <summary>Bumped when the built-in default activity groups / whitelist expand, so existing
    /// users' saved configs can additively merge in the new entries on next launch.</summary>
    // v3: re-run migration to clear any leftover exe-name music whitelist that the
    // stricter v2 SetEquals check failed to migrate (it only matched the exact 9-entry
    // legacy default; users who'd pared it down stayed broken).
    public const int CurrentConfigVersion = 3;

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

    // ---- Music app whitelist ----
    // Empty = allow ALL media sources. This is the default because the whitelist matches a
    // player's SourceAppUserModelId (the SMTC session id), which is NOT the same as the
    // process exe name — guessing exe names dropped valid players (e.g. NetEase, whose SMTC
    // id != "cloudmusic.exe"). Users who want to restrict can add real source ids via the
    // "从运行中的应用选择…" picker, which lists the actual SMTC session ids.
    public static List<string> MusicAppWhitelist() => new();

    /// <summary>The previously-shipped non-empty default whitelist. Used to detect configs
    /// the user never customized, so they can be migrated to empty (= allow all).</summary>
    public static readonly string[] LegacyDefaultMusicWhitelist =
    {
        "Spotify.exe", "cloudmusic.exe", "QQMusic.exe", "kugou.exe", "foobar2000.exe",
        "AppleInc.AppleMusicWin_nzyj5cx40ttqa!App",
        "Microsoft.ZuneMusic_8wekyb3d8bbwe!Microsoft.ZuneMusic",
        "msedge.exe", "chrome.exe",
    };

    // ---- Activity groups (process exe names, lower-cased) ----
    // Order matters: the first enabled group containing the process wins.

    public static List<ActivityGroup> ActivityGroups() => new()
    {
        new ActivityGroup("在工作&研究", new[]
        {
            // Office / 文档
            "winword.exe", "excel.exe", "powerpnt.exe", "onenote.exe", "onenotem.exe",
            "outlook.exe", "msaccess.exe", "mspub.exe", "visio.exe", "winproj.exe",
            "wps.exe", "et.exe", "wpp.exe", "wpscloudsvr.exe", "pdfpro.exe",
            "acrobat.exe", "acrord32.exe", "foxitpdfreader.exe", "foxit reader.exe", "sumatrapdf.exe",
            // 企业 IM / 协作(归到工作)
            "feishu.exe", "lark.exe", "dingtalk.exe", "wxwork.exe", "wework.exe",
            "ms-teams.exe", "teams.exe", "lync.exe", "corplink.exe", "sunloginclient.exe", "todesk.exe",
            // 笔记 / 知识
            "notion.exe", "obsidian.exe", "logseq.exe", "typora.exe", "evernote.exe",
            "youdaonote.exe", "wiznote.exe", "joplin.exe", "anytype.exe", "siyuan.exe",
            // 云盘
            "onedrive.exe", "googledrivefs.exe", "dropbox.exe", "baidunetdisk.exe", "alipan.exe",
        }),
        new ActivityGroup("在搞研发", new[]
        {
            // 编辑器 / IDE
            "code.exe", "code - insiders.exe", "cursor.exe", "trae.exe", "windsurf.exe",
            "zed.exe", "devenv.exe", "rider64.exe", "idea64.exe", "goland64.exe",
            "pycharm64.exe", "webstorm64.exe", "clion64.exe", "phpstorm64.exe",
            "rubymine64.exe", "rustrover64.exe", "datagrip64.exe", "studio64.exe",
            "sublime_text.exe", "notepad++.exe", "atom.exe", "010editor.exe", "fleet.exe",
            // 数据库 / API / 调试
            "postman.exe", "apifox.exe", "insomnia.exe", "bruno.exe",
            "another redis desktop manager.exe", "anotherredisdesktopmanager.exe",
            "redisinsight.exe", "compass.exe", "navicat.exe", "dbeaver.exe", "heidisql.exe",
            "tableplus.exe", "fiddler.exe", "fiddler everywhere.exe", "charles.exe", "wireshark.exe",
            // 容器 / 版本控制 / 工具
            "docker desktop.exe", "podman desktop.exe", "rancher desktop.exe",
            "gitkraken.exe", "sourcetree.exe", "fork.exe", "github desktop.exe",
            "tortoisegitproc.exe", "ollama.exe", "ollama app.exe", "lm studio.exe",
        }),
        new ActivityGroup("在设计", new[]
        {
            "photoshop.exe", "illustrator.exe", "afterfx.exe", "adobe premiere pro.exe",
            "lightroom.exe", "acrobat.exe", "figma.exe", "xd.exe", "adobe xd.exe",
            "afdesign.exe", "afphoto.exe", "afpub.exe", "blender.exe", "sketchup.exe",
            "coreldrw.exe", "axure.exe", "pixso.exe", "mastergo.exe", "cad.exe", "acad.exe",
        }),
        new ActivityGroup("在开会", new[]
        {
            "zoom.exe", "webex.exe", "atmgr.exe", "voov.exe", "wemeetapp.exe",
            "feishumeeting.exe", "classin.exe", "gotomeeting.exe", "bluejeans.exe",
        }),
        new ActivityGroup("在浏览", new[]
        {
            "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe",
            "vivaldi.exe", "arc.exe", "chromium.exe", "thorium.exe", "librewolf.exe",
            "floorp.exe", "zen.exe", "360se.exe", "360chromex.exe", "qqbrowser.exe",
            "sogouexplorer.exe", "maxthon.exe", "ucbrowser.exe", "tor browser.exe", "dragon.exe",
        }),
        new ActivityGroup("在终端", new[]
        {
            "windowsterminal.exe", "wt.exe", "powershell.exe", "pwsh.exe", "cmd.exe",
            "mintty.exe", "alacritty.exe", "wezterm-gui.exe", "conemu64.exe", "hyper.exe",
            "tabby.exe", "putty.exe", "kitty.exe", "mobaxterm.exe", "xshell.exe",
            "securecrt.exe", "termius.exe", "finalshell.exe", "warp.exe",
        }),
        new ActivityGroup("在娱乐", new[]
        {
            // 音乐
            "spotify.exe", "cloudmusic.exe", "qqmusic.exe", "kugou.exe", "kuwo.exe",
            "applemusic.exe", "aimp.exe", "musicbee.exe", "foobar2000.exe",
            // 视频 / 播放器
            "bilibili.exe", "douyin.exe", "potplayermini64.exe", "potplayermini.exe",
            "vlc.exe", "mpv.exe", "mpc-hc64.exe", "kmplayer.exe", "qqlive.exe",
            "qyclient.exe", "youku.exe", "miguvideo.exe", "netflix.exe",
            // 游戏 / 直播
            "steam.exe", "epicgameslauncher.exe", "wegame.exe", "battle.net.exe",
            "obs64.exe", "obs32.exe",
        }),
        new ActivityGroup("在社交", new[]
        {
            "qq.exe", "tim.exe", "weixin.exe", "wechat.exe", "telegram.exe",
            "discord.exe", "whatsapp.exe", "messenger.exe", "skype.exe", "signal.exe",
            "line.exe", "kakaotalk.exe", "viber.exe", "slack.exe", "element.exe", "zalo.exe",
        }),
    };
}
