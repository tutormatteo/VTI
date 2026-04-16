using System.Windows;
using VTI.App.ViewModels;

namespace VTI.App;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainViewModel();
    }
}
