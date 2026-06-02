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
    private const string ReleasesUrl = "https://github.com/wujunyi792/share-my-status-plus/releases";

    private readonly AppLogger _logger = AppLogger.App;

    private Mutex? _singleInstanceMutex;
    private bool _ownsMutex;
    private NotifyIcon? _trayIcon;
    private ToolStripMenuItem? _toggleItem;
    private ToolStripMenuItem? _statusItem;
    private ToolStripMenuItem? _statusPageItem;
    private ToolStripMenuItem? _signatureItem;
    private StatusReporter? _reporter;
    private AppConfiguration? _config;
    private SettingsWindow? _settingsWindow;
    private string? _lastNotifiedError;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

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

        AutostartService.SetEnabled(_config.LaunchAtLogin);

        SetupTray();

        if (!_config.IsValid())
        {
            // First run (or incomplete config): guide the user to set up.
            OpenSettings();
        }
        else if (_config.ReporterEnabled)
        {
            _ = _reporter.StartAsync();
        }

        UpdateTrayUi();
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
        menu.Items.Add(new ToolStripMenuItem("检查更新", null, (_, _) => OpenUrl(ReleasesUrl)));
        menu.Items.Add(new ToolStripMenuItem("关于", null, (_, _) => ShowAbout()));
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("退出", null, (_, _) => ExitApp()));

        _trayIcon = new NotifyIcon
        {
            Icon = LoadTrayIcon(),
            Visible = true,
            Text = "Share My Status",
            ContextMenuStrip = menu,
        };
        _trayIcon.DoubleClick += (_, _) => OpenSettings();
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
            _statusItem.Text = _reporter.ReportingStatus;

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

    private static string Truncate(string s, int max) => s.Length > max ? s[..max] : s;

    // ---- Commands ----

    private async void OnToggleClick(object? sender, EventArgs e)
    {
        if (_reporter == null || _config == null)
            return;

        if (_reporter.IsReporting)
        {
            await _reporter.StopAsync();
            _config.ReporterEnabled = false;
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

        if (!_reporter.IsReporting && !_config.ReporterEnabled)
            ShowBalloon("Share My Status", "已停止上报", ToolTipIcon.Info);

        SaveConfig();
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
        _config.Save();
        AutostartService.SetEnabled(_config.LaunchAtLogin);
        _reporter.ApplyConfiguration(_config);
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
        if (_reporter != null)
            await _reporter.StopAsync();
        SaveConfig();
        Shutdown();
    }

    private void SaveConfig()
    {
        try
        {
            _config?.Save();
        }
        catch (Exception ex)
        {
            _logger.Error("Failed to save configuration", ex);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_trayIcon != null)
        {
            _trayIcon.Visible = false;
            _trayIcon.Dispose();
            _trayIcon = null;
        }

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
