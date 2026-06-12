using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using ShareMyStatusClient.Utilities;

namespace ShareMyStatusClient.Views;

/// <summary>A reusable multi-select picker over currently running windowed apps.
/// Returns selected process executable names.</summary>
public partial class ProcessPickerWindow : Window
{
    private readonly ObservableCollection<PickItem> _items = new();
    private readonly ICollectionView _view;
    private string _search = string.Empty;

    public IReadOnlyList<string> SelectedIdentifiers { get; private set; } = Array.Empty<string>();

    public ProcessPickerWindow(string title)
    {
        InitializeComponent();
        Title = title;

        _view = CollectionViewSource.GetDefaultView(_items);
        _view.Filter = FilterItem;
        List.ItemsSource = _view;

        Loaded += async (_, _) => await ReloadAsync();
    }

    private bool FilterItem(object obj)
    {
        if (obj is not PickItem item)
            return false;
        if (string.IsNullOrWhiteSpace(_search))
            return true;
        return item.Display.Contains(_search, StringComparison.CurrentCultureIgnoreCase)
               || item.Identifier.Contains(_search, StringComparison.CurrentCultureIgnoreCase);
    }

    private async Task ReloadAsync()
    {
        LblStatus.Text = "正在扫描运行中的应用…";
        BtnRefresh.IsEnabled = false;

        var existing = _items.Where(i => i.IsChecked).Select(i => i.Identifier)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        try
        {
            var apps = await Task.Run(ProcessHelper.GetWindowedProcesses);

            _items.Clear();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var app in apps)
            {
                if (seen.Add(app.ProcessName))
                    _items.Add(new PickItem(app.ProcessName, app.DisplayName, existing.Contains(app.ProcessName)));
            }

            LblStatus.Text = _items.Count == 0
                ? "未发现可选应用，可手动输入。"
                : $"共 {_items.Count} 个应用";
            _view.Refresh();
        }
        catch (Exception ex)
        {
            LblStatus.Text = "扫描失败：" + ex.Message;
        }
        finally
        {
            BtnRefresh.IsEnabled = true;
        }
    }

    private void OnSearchChanged(object sender, TextChangedEventArgs e)
    {
        _search = TxtSearch.Text;
        _view.Refresh();
    }

    private async void OnRefreshClick(object sender, RoutedEventArgs e) => await ReloadAsync();

    private void OnOkClick(object sender, RoutedEventArgs e)
    {
        SelectedIdentifiers = _items.Where(i => i.IsChecked)
            .Select(i => i.Identifier)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        DialogResult = true;
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}

public sealed class PickItem : INotifyPropertyChanged
{
    private bool _isChecked;

    public string Identifier { get; }
    public string Display { get; }

    public bool IsChecked
    {
        get => _isChecked;
        set { _isChecked = value; PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsChecked))); }
    }

    public PickItem(string identifier, string display, bool isChecked)
    {
        Identifier = identifier;
        Display = display;
        _isChecked = isChecked;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
