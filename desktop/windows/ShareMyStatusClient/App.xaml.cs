using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows;
using System.Drawing;
using System.Windows.Forms;
using ShareMyStatusClient.Models.Settings;
using ShareMyStatusClient.Services;
using ShareMyStatusClient.Utilities;
using ShareMyStatusClient.Views;
using Velopack;
using Application = System.Windows.Application;
using MessageBox = System.Windows.MessageBox;

namespace ShareMyStatusClient;

/// <summary>
/// Tray host and coordinator. Owns the configuration, the <see cref="StatusReporter"/>,
/// and the notification-area icon. The Windows analogue of the macOS AppCoordinator.
/// </summary>
public partial class App : Application
{
    private const string MutexName = "ShareMyStatus.SingleInstance.{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}";
    private const string RepoUrl = "https://github.com/wujunyi792/share-my-status-plus";
    private const string ReleasesUrl = RepoUrl + "/releases";

    private readonly AppLogger _logger = AppLogger.App;

    private Mutex? _singleInstanceMutex;
    private bool _ownsMutex;
    private NotifyIcon? _trayIcon;
    private Icon? _trayIconImage;
    private ToolStripMenuItem? _toggleItem;
    private ToolStripMenuItem? _statusItem;
    private ToolStripMenuItem? _statusPageItem;
    private ToolStripMenuItem? _signatureItem;
    private ToolStripMenuItem? _updateItem;
    private StatusReporter? _reporter;
    private AppConfiguration? _config;
    private UpdateService? _updateService;
    private SettingsWindow? _settingsWindow;
    private string? _lastNotifiedError;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Last-resort handlers so background/fire-and-forget failures are logged, not lost.
        DispatcherUnhandledException += (_, args) =>
        {
            _logger.Error("Unhandled UI exception", args.Exception);
            args.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, args) =>
        {
            if (args.ExceptionObject is Exception ex)
                _logger.Error("Unhandled domain exception", ex);
        };
        System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (_, args) =>
        {
            _logger.Error("Unobserved task exception", args.Exception);
            args.SetObserved();
        };

        _singleInstanceMutex = new Mutex(true, MutexName, out _ownsMutex);
        if (!_ownsMutex)
        {
            MessageBox.Show("Share My Status 已在运行（请查看系统托盘）。", "Share My Status");
            Shutdown();
            return;
        }

        _logger.Info("Application starting");

        _config = AppConfiguration.Load();
        _reporter = new StatusReporter();
        _reporter.Changed += OnReporterChanged;
        _reporter.ApplyConfiguration(_config);
        _updateService = new UpdateService(RepoUrl);

        AutostartService.SetEnabled(_config.LaunchAtLogin);

        SetupTray();

        var launchedAtLogin = e.Args.Any(a => string.Equals(a, "--autostart", StringComparison.OrdinalIgnoreCase));

        if (!_config.IsValid())
        {
            // Incomplete config: guide setup on a manual launch, but stay silent (just the
            // tray) when auto-started at login so we don't nag the user every sign-in.
            if (!launchedAtLogin)
                OpenSettings();
        }
        else if (_config.ReporterEnabled)
        {
            _ = _reporter.StartAsync();
        }

        UpdateTrayUi();

        // One-time hint: Windows hides new tray icons in the overflow (▲), so users often
        // can't find where the app went. Tell them once.
        if (!_config.HasShownTrayHint)
        {
            _config.HasShownTrayHint = true;
            SaveConfig();
            ShowBalloon(
                "Share My Status 正在运行",
                "图标在屏幕右下角通知区域（可能折叠在 ▲ 里）。点此或右键它即可设置 / 开始 / 停止上报。",
                ToolTipIcon.Info);
        }

        // Best-effort silent update check shortly after launch.
        _ = CheckUpdatesAsync(silent: true);
    }

    // ---- Tray ----

    private void SetupTray()
    {
        var menu = new ContextMenuStrip();

        _statusItem = new ToolStripMenuItem("未启动") { Enabled = false };
        menu.Items.Add(_statusItem);
        menu.Items.Add(new ToolStripSeparator());

        _toggleItem = new ToolStripMenuItem("开始上报", null, OnToggleClick);
        menu.Items.Add(_toggleItem);
        menu.Items.Add(new ToolStripMenuItem("设置...", null, (_, _) => OpenSettings()));
        menu.Items.Add(new ToolStripSeparator());

        _statusPageItem = new ToolStripMenuItem("打开我的状态页", null, (_, _) => OpenStatusPage())
        {
            Enabled = false,
        };
        menu.Items.Add(_statusPageItem);
        _signatureItem = new ToolStripMenuItem("自定义飞书签名", null, (_, _) => OpenSignaturePage())
        {
            Enabled = false,
        };
        menu.Items.Add(_signatureItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(new ToolStripMenuItem("打开日志文件夹", null, (_, _) => OpenLogs()));
        _updateItem = new ToolStripMenuItem("检查更新", null, (_, _) => _ = CheckUpdatesAsync(silent: false));
        menu.Items.Add(_updateItem);
        menu.Items.Add(new ToolStripMenuItem("关于", null, (_, _) => ShowAbout()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("退出", null, (_, _) => ExitApp()));

        var trayIcon = LoadTrayIcon();
        // SystemIcons.Application is a shared singleton and must not be disposed; only
        // hold a reference to icons we created so we can release their GDI handle on exit.
        _trayIconImage = ReferenceEquals(trayIcon, SystemIcons.Application) ? null : trayIcon;

        _trayIcon = new NotifyIcon
        {
            Icon = trayIcon,
            Visible = true,
            Text = "Share My Status",
            ContextMenuStrip = menu,
        };
        _trayIcon.DoubleClick += (_, _) => OpenSettings();
        // Left single-click also opens settings (common Windows tray behaviour).
        _trayIcon.MouseClick += (_, args) =>
        {
            if (args.Button == MouseButtons.Left)
                OpenSettings();
        };
        // Clicking a notification opens settings (e.g. the first-run "where's the icon" hint).
        _trayIcon.BalloonTipClicked += (_, _) => OpenSettings();
    }

    private static Icon LoadTrayIcon()
    {
        // Prefer the embedded multi-size .ico so the tray gets a crisp small frame.
        try
        {
            var resource = Application.GetResourceStream(
                new Uri("pack://application:,,,/Resources/app.ico"));
            if (resource != null)
            {
                using var stream = resource.Stream;
                return new Icon(stream, SystemInformation.SmallIconSize);
            }
        }
        catch
        {
            // Fall through to the exe-associated icon.
        }

        try
        {
            var exe = Environment.ProcessPath;
            if (!string.IsNullOrEmpty(exe))
            {
                var icon = Icon.ExtractAssociatedIcon(exe);
                if (icon != null)
                    return icon;
            }
        }
        catch
        {
            // Fall back below.
        }

        return SystemIcons.Application;
    }

    private void OnReporterChanged(object? sender, EventArgs e)
    {
        Dispatcher.BeginInvoke(new Action(UpdateTrayUi));
    }

    private void UpdateTrayUi()
    {
        if (_trayIcon == null || _reporter == null)
            return;

        var reporting = _reporter.IsReporting;
        if (_toggleItem != null)
            _toggleItem.Text = reporting ? "停止上报" : "开始上报";
        if (_statusItem != null)
        {
            var needsSetup = _config != null && !_config.IsValid();
            _statusItem.Text = (!reporting && needsSetup) ? "未配置 — 请打开设置" : _reporter.ReportingStatus;
        }

        var resources = _reporter.ClientResources;
        if (_statusPageItem != null)
            _statusPageItem.Enabled = !string.IsNullOrEmpty(resources?.UserDocUrl);
        if (_signatureItem != null)
            _signatureItem.Enabled = !string.IsNullOrEmpty(resources?.FeishuSignatureDiyUrl);

        // Tooltip: status line plus a live summary (NotifyIcon.Text is capped at 63 chars).
        var tip = $"Share My Status — {_reporter.ReportingStatus}";
        if (reporting)
        {
            var summary = _reporter.GetStatusSummary();
            if (summary != "无状态数据")
                tip = $"{_reporter.ReportingStatus}\n{summary}";
        }
        _trayIcon.Text = Truncate(tip, 63);

        // Surface report errors as a balloon, once per distinct error.
        var error = _reporter.LastError?.Message;
        if (reporting && !string.IsNullOrEmpty(error))
        {
            if (error != _lastNotifiedError)
            {
                _lastNotifiedError = error;
                ShowBalloon("上报出错", error!, ToolTipIcon.Warning);
            }
        }
        else if (string.IsNullOrEmpty(error))
        {
            _lastNotifiedError = null;
        }
    }

    private static string Truncate(string s, int max)
    {
        if (s.Length <= max)
            return s;
        var end = max;
        // Don't split a UTF-16 surrogate pair (would produce an invalid char).
        if (char.IsHighSurrogate(s[end - 1]))
            end--;
        return s[..end];
    }

    // ---- Commands ----

    private async void OnToggleClick(object? sender, EventArgs e)
    {
        if (_reporter == null || _config == null)
            return;

        try
        {
            if (_reporter.IsReporting)
            {
                await _reporter.StopAsync();
                _config.ReporterEnabled = false;
                ShowBalloon("Share My Status", "已停止上报", ToolTipIcon.Info);
            }
            else
            {
                if (!_config.IsValid())
                {
                    MessageBox.Show("请先在「设置」中填写服务器地址与 Secret Key。", "Share My Status");
                    OpenSettings();
                    return;
                }
                await _reporter.StartAsync();
                _config.ReporterEnabled = true;
                ShowBalloon("Share My Status", "已开始上报状态", ToolTipIcon.Info);
            }

            SaveConfig();
        }
        catch (Exception ex)
        {
            _logger.Error("Toggle reporting failed", ex);
            ShowBalloon("Share My Status", "操作失败：" + ex.Message, ToolTipIcon.Error);
        }

        UpdateTrayUi();
    }

    private void OpenSettings()
    {
        if (_config == null || _reporter == null)
            return;

        if (_settingsWindow != null)
        {
            _settingsWindow.Activate();
            return;
        }

        _settingsWindow = new SettingsWindow(_config, ApplyConfigFromSettings, _reporter.TestConnectionAsync);
        _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    private void ApplyConfigFromSettings(AppConfiguration updated)
    {
        if (_config == null || _reporter == null)
            return;

        _config.CopyFrom(updated);
        AutostartService.SetEnabled(_config.LaunchAtLogin);
        _reporter.ApplyConfiguration(_config);

        // Auto-start reporting after a valid save so users don't have to hunt for the
        // tray toggle (a common point of confusion).
        if (_config.IsValid() && !_reporter.IsReporting)
            _config.ReporterEnabled = true;

        if (!SaveConfig())
            MessageBox.Show("配置保存失败，请检查磁盘权限后重试。", "Share My Status");

        if (_config.ReporterEnabled && _config.IsValid() && !_reporter.IsReporting)
            _ = StartReportingWithFeedbackAsync();
        else
            UpdateTrayUi();
    }

    private async Task StartReportingWithFeedbackAsync()
    {
        if (_reporter == null)
            return;
        try
        {
            await _reporter.StartAsync();
            ShowBalloon("Share My Status", "配置已保存，已开始上报。右键通知区域图标可随时停止。", ToolTipIcon.Info);
        }
        catch (Exception ex)
        {
            _logger.Error("Auto-start after save failed", ex);
        }
        UpdateTrayUi();
    }

    private void OpenStatusPage()
    {
        var url = _reporter?.ClientResources?.UserDocUrl;
        if (!string.IsNullOrEmpty(url))
            OpenUrl(url!);
    }

    private void OpenSignaturePage()
    {
        var url = _reporter?.ClientResources?.FeishuSignatureDiyUrl;
        if (!string.IsNullOrEmpty(url))
            OpenUrl(url!);
    }

    private void OpenUrl(string url)
    {
        try
        {
            Process.Start(new ProcessStartInfo { FileName = url, UseShellExecute = true });
        }
        catch (Exception ex)
        {
            _logger.Error($"Failed to open URL {url}", ex);
        }
    }

    private async Task CheckUpdatesAsync(bool silent)
    {
        if (_updateService == null)
            return;

        if (!_updateService.IsInstalled)
        {
            // Loose/dev build: no in-place update channel, fall back to manual download.
            if (!silent)
                OpenUrl(ReleasesUrl);
            return;
        }

        UpdateInfo? info;
        try
        {
            info = await _updateService.CheckAsync();
        }
        catch (Exception ex)
        {
            _logger.Error("Update check failed", ex);
            if (!silent)
                MessageBox.Show("检查更新失败，请稍后重试。", "Share My Status");
            return;
        }

        if (info == null)
        {
            if (!silent)
                MessageBox.Show("已是最新版本。", "Share My Status");
            return;
        }

        var version = info.TargetFullRelease?.Version?.ToString() ?? "新版本";

        if (silent)
        {
            if (_updateItem != null)
                _updateItem.Text = $"更新到 v{version}";
            ShowBalloon("发现新版本 v" + version, $"点击托盘菜单「更新到 v{version}」立即更新", ToolTipIcon.Info);
            return;
        }

        var confirm = MessageBox.Show(
            $"发现新版本 v{version}。\n下载并重启更新吗？", "Share My Status",
            MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;
        if (!confirm)
            return;

        try
        {
            ShowBalloon("Share My Status", "正在下载更新…", ToolTipIcon.Info);
            await _updateService.DownloadAndRestartAsync(info); // process exits and relaunches
        }
        catch (Exception ex)
        {
            _logger.Error("Update apply failed", ex);
            MessageBox.Show("更新失败：" + ex.Message, "Share My Status");
        }
    }

    private void ShowAbout()
    {
        var version = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "1.0";
        MessageBox.Show(
            $"Share My Status — Windows 客户端\n版本 {version}\n\n采集音乐 / 系统 / 活动并上报到你配置的服务器。\n{ReleasesUrl}",
            "关于 Share My Status");
    }

    private void ShowBalloon(string title, string text, ToolTipIcon icon)
    {
        try
        {
            _trayIcon?.ShowBalloonTip(4000, title, text, icon);
        }
        catch
        {
            // Balloons are best-effort.
        }
    }

    private void OpenLogs()
    {
        try
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "ShareMyStatus", "logs");
            Directory.CreateDirectory(dir);
            Process.Start(new ProcessStartInfo { FileName = dir, UseShellExecute = true });
        }
        catch (Exception ex)
        {
            _logger.Error("Failed to open log folder", ex);
        }
    }

    private async void ExitApp()
    {
        try
        {
            if (_reporter != null)
                await _reporter.StopAsync();
        }
        catch (Exception ex)
        {
            _logger.Error("Stop on exit failed", ex);
        }
        finally
        {
            SaveConfig();
            Shutdown();
        }
    }

    private bool SaveConfig()
    {
        try
        {
            _config?.Save();
            return true;
        }
        catch (Exception ex)
        {
            _logger.Error("Failed to save configuration", ex);
            return false;
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_reporter != null)
            _reporter.Changed -= OnReporterChanged;

        if (_trayIcon != null)
        {
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            _trayIcon = null;
        }

        // Dispose the icon we created (after the tray no longer uses it).
        _trayIconImage?.Dispose();
        _trayIconImage = null;

        // Reporting was already stopped in ExitApp; release owned services.
        _reporter?.Dispose();

        if (_singleInstanceMutex != null)
        {
            try
            {
                if (_ownsMutex)
                    _singleInstanceMutex.ReleaseMutex();
            }
            catch
            {
                // ignore
            }
            _singleInstanceMutex.Dispose();
            _singleInstanceMutex = null;
        }

        _logger.Info("Application exited");
        base.OnExit(e);
    }
}
