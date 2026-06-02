using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;
using ShareMyStatusClient.Models.Settings;

namespace ShareMyStatusClient.Views;

public partial class SettingsWindow : Window
{
    private readonly AppConfiguration _working;
    private readonly Action<AppConfiguration> _onApply;
    private readonly Func<string, string, Task<(bool Ok, string Message)>> _testConnection;
    private readonly ObservableCollection<ActivityGroupEditModel> _groups = new();

    public SettingsWindow(
        AppConfiguration current,
        Action<AppConfiguration> onApply,
        Func<string, string, Task<(bool Ok, string Message)>> testConnection)
    {
        InitializeComponent();
        _working = current.Clone();
        _onApply = onApply;
        _testConnection = testConnection;
        GroupsList.ItemsSource = _groups;
        LoadIntoUi(_working);
    }

    private void LoadIntoUi(AppConfiguration cfg)
    {
        TxtEndpoint.Text = cfg.EndpointUrl;
        TxtSecret.Text = cfg.SecretKey;
        ChkMusic.IsChecked = cfg.MusicReportingEnabled;
        ChkSystem.IsChecked = cfg.SystemReportingEnabled;
        ChkActivity.IsChecked = cfg.ActivityReportingEnabled;
        SldSystem.Value = cfg.SystemPollingInterval;
        SldActivity.Value = cfg.ActivityPollingInterval;
        ChkAutostart.IsChecked = cfg.LaunchAtLogin;
        TxtWhitelist.Text = string.Join(Environment.NewLine, cfg.MusicAppWhitelist);

        _groups.Clear();
        foreach (var g in cfg.ActivityGroups)
            _groups.Add(ActivityGroupEditModel.From(g));
        if (_groups.Count > 0)
            GroupsList.SelectedIndex = 0;
    }

    private AppConfiguration BuildConfig()
    {
        // Clone keeps non-edited fields such as ReporterEnabled.
        var cfg = _working.Clone();
        cfg.EndpointUrl = TxtEndpoint.Text.Trim();
        cfg.SecretKey = TxtSecret.Text.Trim();
        cfg.MusicReportingEnabled = ChkMusic.IsChecked == true;
        cfg.SystemReportingEnabled = ChkSystem.IsChecked == true;
        cfg.ActivityReportingEnabled = ChkActivity.IsChecked == true;
        cfg.SystemPollingInterval = SldSystem.Value;
        cfg.ActivityPollingInterval = SldActivity.Value;
        cfg.LaunchAtLogin = ChkAutostart.IsChecked == true;
        cfg.MusicAppWhitelist = ParseLines(TxtWhitelist.Text);
        cfg.ActivityGroups = _groups
            .Select(g => g.ToGroup())
            .Where(g => !string.IsNullOrWhiteSpace(g.Name))
            .ToList();
        return cfg;
    }

    private static List<string> ParseLines(string text) =>
        text.Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct()
            .ToList();

    // ---- Actions ----

    private void OnSaveClick(object sender, RoutedEventArgs e)
    {
        var endpoint = TxtEndpoint.Text.Trim();
        if (string.IsNullOrWhiteSpace(endpoint) || !Uri.TryCreate(endpoint, UriKind.Absolute, out _))
        {
            MessageBox.Show(this, "服务器地址格式无效，请填写完整的上报 Endpoint。", "无法保存",
                MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        if (string.Equals(endpoint, DefaultSettings.EndpointUrl, StringComparison.OrdinalIgnoreCase))
        {
            MessageBox.Show(this, "请填写你自己的服务器地址（当前仍是占位示例地址）。", "无法保存",
                MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        if (_groups.Any(g => string.IsNullOrWhiteSpace(g.Name)))
        {
            MessageBox.Show(this, "存在未命名的活动分组，请填写名称或删除后再保存。", "无法保存",
                MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        if (string.IsNullOrWhiteSpace(TxtSecret.Text))
        {
            var proceed = MessageBox.Show(this,
                "Secret Key 为空，上报将无法启动。仍要保存吗？", "提示",
                MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (proceed != MessageBoxResult.Yes)
                return;
        }

        var cfg = BuildConfig();
        _onApply(cfg);
        // Window is shown modeless from the tray, so don't touch DialogResult.
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        Close();
    }

    private void OnAddGroupClick(object sender, RoutedEventArgs e)
    {
        var model = new ActivityGroupEditModel { Name = "新分组", IsEnabled = true };
        _groups.Add(model);
        GroupsList.SelectedItem = model;
    }

    private void OnRemoveGroupClick(object sender, RoutedEventArgs e)
    {
        if (GroupsList.SelectedItem is ActivityGroupEditModel model)
        {
            var index = _groups.IndexOf(model);
            _groups.Remove(model);
            if (_groups.Count > 0)
                GroupsList.SelectedIndex = Math.Min(index, _groups.Count - 1);
        }
    }

    private void OnImportClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "JSON 配置 (*.json)|*.json|所有文件 (*.*)|*.*",
            Title = "导入配置",
        };
        if (dialog.ShowDialog(this) != true)
            return;

        try
        {
            var text = File.ReadAllText(dialog.FileName);
            var imported = _working.Clone();
            var error = imported.ImportFromJson(text);
            if (error != null)
            {
                MessageBox.Show(this, error, "导入失败", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            _working.CopyFrom(imported);
            LoadIntoUi(_working);
            var note = string.IsNullOrWhiteSpace(_working.SecretKey)
                ? "配置已导入。该配置不含 Secret Key，请手动填写后保存。"
                : "配置已导入，请确认无误后保存。";
            MessageBox.Show(this, note, "成功", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"文件读取失败: {ex.Message}", "导入失败",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void OnExportClick(object sender, RoutedEventArgs e)
    {
        var includeSecret = MessageBox.Show(this,
            "是否在导出文件中包含 Secret Key？\n\n选择「否」可安全分享配置。", "导出配置",
            MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes;

        var dialog = new SaveFileDialog
        {
            Filter = "JSON 配置 (*.json)|*.json",
            Title = "导出配置",
            FileName = "share-my-status-config.json",
        };
        if (dialog.ShowDialog(this) != true)
            return;

        try
        {
            var json = BuildConfig().ExportToJson(includeSecret);
            File.WriteAllText(dialog.FileName, json);
            MessageBox.Show(this, "配置已导出。", "成功", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"文件写入失败: {ex.Message}", "导出失败",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private async void OnTestClick(object sender, RoutedEventArgs e)
    {
        var endpoint = TxtEndpoint.Text.Trim();
        var secret = TxtSecret.Text.Trim();

        BtnTest.IsEnabled = false;
        LblTest.Foreground = Brushes.Gray;
        LblTest.Text = "正在测试…";
        try
        {
            var (ok, message) = await _testConnection(endpoint, secret);
            if (!IsLoaded)
                return; // window closed while awaiting
            LblTest.Foreground = ok ? Brushes.Green : Brushes.OrangeRed;
            LblTest.Text = (ok ? "✓ " : "✗ ") + message;
        }
        catch (Exception ex)
        {
            if (IsLoaded)
            {
                LblTest.Foreground = Brushes.OrangeRed;
                LblTest.Text = "✗ " + ex.Message;
            }
        }
        finally
        {
            if (IsLoaded)
                BtnTest.IsEnabled = true;
        }
    }

    private void OnPickMusicClick(object sender, RoutedEventArgs e)
    {
        var existing = ParseLines(TxtWhitelist.Text);
        var picked = PickApps("选择媒体应用 (音乐白名单)", includeMediaSources: true);
        if (picked == null)
            return;

        var merged = existing
            .Concat(picked)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        TxtWhitelist.Text = string.Join(Environment.NewLine, merged);
    }

    private void OnPickActivityClick(object sender, RoutedEventArgs e)
    {
        if (GroupsList.SelectedItem is not ActivityGroupEditModel model)
        {
            MessageBox.Show(this, "请先在左侧选择一个分组。", "提示",
                MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var picked = PickApps("选择应用 (添加到分组)", includeMediaSources: false);
        if (picked == null)
            return;

        var existing = model.ProcessNamesText
            .Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var merged = existing
            .Concat(picked.Select(p => p.ToLowerInvariant()))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        model.ProcessNamesText = string.Join(Environment.NewLine, merged);
    }

    private IReadOnlyList<string>? PickApps(string title, bool includeMediaSources)
    {
        var picker = new ProcessPickerWindow(title, includeMediaSources) { Owner = this };
        return picker.ShowDialog() == true ? picker.SelectedIdentifiers : null;
    }

    private void OnResetClick(object sender, RoutedEventArgs e)
    {
        var confirm = MessageBox.Show(this, "确定要恢复为默认设置吗？", "恢复默认",
            MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (confirm != MessageBoxResult.Yes)
            return;

        _working.ResetToDefaults();
        LoadIntoUi(_working);
    }
}
