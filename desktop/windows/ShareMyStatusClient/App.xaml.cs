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

    private readonly AppLogger _logger = AppLogger.App;

    private Mutex? _singleInstanceMutex;
    private bool _ownsMutex;
    private NotifyIcon? _trayIcon;
    private ToolStripMenuItem? _toggleItem;
    private ToolStripMenuItem? _statusItem;
    private StatusReporter? _reporter;
    private AppConfiguration? _config;
    private SettingsWindow? _settingsWindow;

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

        if (_config.ReporterEnabled && _config.IsValid())
            _ = _reporter.StartAsync();

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
        menu.Items.Add(new ToolStripMenuItem("打开日志文件夹", null, (_, _) => OpenLogs()));
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

        var tip = $"Share My Status — {_reporter.ReportingStatus}";
        // NotifyIcon.Text is limited to 63 characters.
        _trayIcon.Text = tip.Length > 63 ? tip[..63] : tip;
    }

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
        }

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

        _settingsWindow = new SettingsWindow(_config, ApplyConfigFromSettings);
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
