using System.Globalization;
using System.Windows.Data;
using VTI.Core;

namespace VTI.App.Converters;

public sealed class SidebarSectionToIndexConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is SidebarSection s ? (int)s : 0;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is int i ? (SidebarSection)Math.Clamp(i, 0, 4) : SidebarSection.Home;
}
