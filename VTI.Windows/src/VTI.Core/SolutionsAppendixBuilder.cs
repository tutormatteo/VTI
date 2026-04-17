using System.Text;

namespace VTI.Core;

/// <summary>Builds the LaTeX longtable for "Appendice: risposte corrette" (test and eserciziario).</summary>
public static class SolutionsAppendixBuilder
{
    private const string MissingAnswerPlaceholder = "---";

    /// <param name="quesitiInPdfOrder">Same order as questions appear in the PDF body (global Domanda 1…n).</param>
    public static string BuildLongTable(IReadOnlyList<Quesito> quesitiInPdfOrder)
    {
        if (quesitiInPdfOrder.Count == 0)
            return "\\textit{Nessuna domanda in elenco.}";

        var sb = new StringBuilder();
        sb.AppendLine(@"\begin{longtable}{@{}r >{\raggedright\arraybackslash}p{2.2cm} >{\raggedright\arraybackslash}p{2.4cm} >{\raggedright\arraybackslash}p{4.2cm} c@{}}");
        sb.AppendLine(@"\toprule");
        sb.AppendLine(@"\textbf{N.} & \textbf{Materia} & \textbf{Argomento} & \textbf{Titolo} & \textbf{Risp.} \\");
        sb.AppendLine(@"\midrule");
        sb.AppendLine(@"\endfirsthead");
        sb.AppendLine(@"\toprule");
        sb.AppendLine(@"\textbf{N.} & \textbf{Materia} & \textbf{Argomento} & \textbf{Titolo} & \textbf{Risp.} \\");
        sb.AppendLine(@"\midrule");
        sb.AppendLine(@"\endhead");
        sb.AppendLine(@"\midrule");
        sb.AppendLine(@"\multicolumn{5}{r@{}}{\small\emph{Continua nella pagina seguente}} \\");
        sb.AppendLine(@"\endfoot");
        sb.AppendLine(@"\bottomrule");
        sb.AppendLine(@"\endlastfoot");

        for (var i = 0; i < quesitiInPdfOrder.Count; i++)
        {
            var q = quesitiInPdfOrder[i];
            var n = (i + 1).ToString(CultureInfo.InvariantCulture);
            var mat = LaTeXTextUtilities.EscapePlainText(q.Materia.RawValue);
            var arg = LaTeXTextUtilities.EscapePlainText(q.Argomento);
            var tit = LaTeXTextUtilities.EscapePlainText(q.Titolo);
            var letter = CorrectAnswerLetter(q.RispostaCorretta);
            sb.Append(n).Append(" & ").Append(mat).Append(" & ").Append(arg).Append(" & ").Append(tit).Append(" & ").Append(letter)
                .AppendLine(@" \\");
        }

        sb.AppendLine(@"\end{longtable}");
        return sb.ToString();
    }

    private static string CorrectAnswerLetter(int? oneBased)
    {
        if (oneBased is < 1 or > 26) return MissingAnswerPlaceholder;
        if (oneBased is null) return MissingAnswerPlaceholder;
        return ((char)('A' + oneBased.Value - 1)).ToString(CultureInfo.InvariantCulture);
    }
}
