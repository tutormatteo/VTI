using System.Globalization;
using System.Text;

namespace VTI.Core;

public static class LaTeXTextUtilities
{
    public static string NormalizeNfc(string? value)
    {
        if (string.IsNullOrEmpty(value)) return value ?? "";
        return value.Normalize(NormalizationForm.FormC);
    }

    /// <summary>Escape text for LaTeX (table cells, section arguments).</summary>
    public static string EscapePlainText(string? value)
    {
        value = NormalizeNfc(value ?? "");
        value = value.Replace("\r\n", "\n", StringComparison.Ordinal)
            .Replace('\r', '\n')
            .Replace('\n', ' ', StringComparison.Ordinal);
        var sb = new StringBuilder(value.Length + 8);
        foreach (var c in value)
        {
            switch (c)
            {
                case '\\':
                    sb.Append(@"\textbackslash{}");
                    break;
                case '{':
                    sb.Append(@"\{");
                    break;
                case '}':
                    sb.Append(@"\}");
                    break;
                case '$':
                    sb.Append(@"\$");
                    break;
                case '&':
                    sb.Append(@"\&");
                    break;
                case '#':
                    sb.Append(@"\#");
                    break;
                case '_':
                    sb.Append(@"\_");
                    break;
                case '%':
                    sb.Append(@"\%");
                    break;
                case '~':
                    sb.Append(@"\textasciitilde{}");
                    break;
                case '^':
                    sb.Append(@"\textasciicircum{}");
                    break;
                default:
                    sb.Append(c);
                    break;
            }
        }
        return sb.ToString();
    }
}
