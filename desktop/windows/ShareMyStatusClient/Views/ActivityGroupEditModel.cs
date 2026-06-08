using System.ComponentModel;
using ShareMyStatusClient.Models.Domain;

namespace ShareMyStatusClient.Views;

/// <summary>Editable representation of an <see cref="ActivityGroup"/> for the settings UI.</summary>
public sealed class ActivityGroupEditModel : INotifyPropertyChanged
{
    private string _name = string.Empty;
    private bool _isEnabled = true;
    private string _processNamesText = string.Empty;

    public string Name
    {
        get => _name;
        set { _name = value; OnChanged(nameof(Name)); }
    }

    public bool IsEnabled
    {
        get => _isEnabled;
        set { _isEnabled = value; OnChanged(nameof(IsEnabled)); }
    }

    /// <summary>Process names, one per line (also accepts comma separation).</summary>
    public string ProcessNamesText
    {
        get => _processNamesText;
        set { _processNamesText = value; OnChanged(nameof(ProcessNamesText)); }
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnChanged(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    public ActivityGroup ToGroup() => new()
    {
        Name = Name.Trim(),
        IsEnabled = IsEnabled,
        ProcessNames = ParseProcessNames(ProcessNamesText),
    };

    public static ActivityGroupEditModel From(ActivityGroup group) => new()
    {
        Name = group.Name,
        IsEnabled = group.IsEnabled,
        ProcessNamesText = string.Join(Environment.NewLine, group.ProcessNames),
    };

    private static List<string> ParseProcessNames(string text) =>
        text.Split(new[] { '\n', '\r', ',' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => s.ToLowerInvariant())
            .Distinct()
            .ToList();
}
