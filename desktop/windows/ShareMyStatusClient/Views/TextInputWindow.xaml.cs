using System.Windows;

namespace ShareMyStatusClient.Views;

/// <summary>A small multi-line text prompt (used to paste configuration JSON).</summary>
public partial class TextInputWindow : Window
{
    public string Result { get; private set; } = string.Empty;

    public TextInputWindow(string title, string hint, string initialText = "")
    {
        InitializeComponent();
        Title = title;
        LblHint.Text = hint;
        Txt.Text = initialText;
        Loaded += (_, _) =>
        {
            Txt.Focus();
            Txt.SelectAll();
        };
    }

    private void OnOkClick(object sender, RoutedEventArgs e)
    {
        Result = Txt.Text;
        DialogResult = true;
        Close();
    }

    private void OnCancelClick(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
