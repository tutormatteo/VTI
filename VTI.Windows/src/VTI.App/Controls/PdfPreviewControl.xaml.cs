using System.IO;
using System.Windows;
using System.Windows.Controls;

namespace VTI.App.Controls;

public partial class PdfPreviewControl : System.Windows.Controls.UserControl
{
    public static readonly DependencyProperty SourcePdfProperty = DependencyProperty.Register(
        nameof(SourcePdf),
        typeof(string),
        typeof(PdfPreviewControl),
        new PropertyMetadata(null, OnSourcePdfChanged));

    public string? SourcePdf
    {
        get => (string?)GetValue(SourcePdfProperty);
        set => SetValue(SourcePdfProperty, value);
    }

    public PdfPreviewControl() => InitializeComponent();

    private async void UserControl_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            await Web.EnsureCoreWebView2Async(null);
            ApplySource();
        }
        catch
        {
            /* WebView2 runtime missing */
        }
    }

    private static void OnSourcePdfChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is PdfPreviewControl c)
            c.ApplySource();
    }

    private void ApplySource()
    {
        if (Web.CoreWebView2 == null)
            return;
        var path = SourcePdf;
        if (string.IsNullOrEmpty(path) || !File.Exists(path))
        {
            try { Web.Source = null; } catch { /* */ }
            return;
        }
        try
        {
            Web.Source = new Uri(path);
        }
        catch
        {
            Web.Source = new Uri("file:///" + path.Replace('\\', '/'));
        }
    }
}
