using System.Text.RegularExpressions;

namespace VTI.Core;

public sealed class QuesitoParserService
{
    private static readonly Regex FileNameRegex = new(
        @"^(.+?) - (.+?) - (.+?) #(\d+)\.txt$",
        RegexOptions.Compiled);

    private static readonly Regex RispostaRegex = new(
        @"Risposta\s+Corretta:\s*(\d+)",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public Quesito ParseFile(string path)
    {
        var fileName = Path.GetFileName(path);
        var meta = ParseFileName(fileName);
        var rawText = File.ReadAllText(path);
        var latexBlock = StripSolutionLine(rawText);
        var domanda = ExtractDomanda(rawText) ?? "";
        var opzioni = ExtractOptions(rawText);
        var risposta = ExtractCorrectAnswer(rawText);
        if (string.IsNullOrWhiteSpace(latexBlock))
            throw AppException.MalformedQuestionFile(fileName);
        return new Quesito
        {
            Materia = meta.Materia,
            Argomento = meta.Argomento,
            Titolo = meta.Titolo,
            Indice = meta.Indice,
            FileName = fileName,
            RawText = rawText,
            DomandaLatex = domanda,
            Opzioni = opzioni,
            RispostaCorretta = risposta,
            UrlFile = path,
            LatexBlock = latexBlock.Trim()
        };
    }

    public (Materia Materia, string Argomento, string Titolo, int Indice) ParseFileName(string fileName)
    {
        var m = FileNameRegex.Match(fileName);
        if (!m.Success || m.Groups.Count < 5)
            throw AppException.MalformedFileName(fileName);
        var materiaStr = m.Groups[1].Value;
        if (!Materia.TryCreate(materiaStr, out var materia))
            throw AppException.MalformedFileName(fileName);
        var indice = int.TryParse(m.Groups[4].Value, out var i) ? i : 0;
        return (materia, m.Groups[2].Value, m.Groups[3].Value, indice);
    }

    private static int? ExtractCorrectAnswer(string text)
    {
        var m = RispostaRegex.Match(text);
        if (!m.Success) return null;
        return int.TryParse(m.Groups[1].Value, out var n) ? n : null;
    }

    private static string StripSolutionLine(string text) =>
        string.Join("\n", text.Split('\n')
            .Where(line => !line.Trim().StartsWith("Risposta Corretta:", StringComparison.OrdinalIgnoreCase)))
            .Trim();

    private static string? ExtractDomanda(string text)
    {
        var idx = text.IndexOf("\\itemdomanda{", StringComparison.Ordinal);
        if (idx < 0) return null;
        var firstOpen = text.IndexOf('{', idx);
        if (firstOpen < 0) return null;
        var first = ExtractBraceContent(text, firstOpen);
        return first?.Content.Trim();
    }

    private static IReadOnlyList<string> ExtractOptions(string text)
    {
        var idx = text.IndexOf("\\itemdomanda{", StringComparison.Ordinal);
        if (idx < 0) return Array.Empty<string>();
        var firstOpen = text.IndexOf('{', idx);
        if (firstOpen < 0) return Array.Empty<string>();
        var first = ExtractBraceContent(text, firstOpen);
        if (first is null) return Array.Empty<string>();
        var second = ExtractBraceContent(text, first.NextIndex);
        if (second is null) return Array.Empty<string>();
        return second.Content.Split('\n')
            .Select(s => s.Trim())
            .Where(s => s.StartsWith("\\item", StringComparison.Ordinal))
            .Select(s => s.Replace("\\item", "", StringComparison.Ordinal).Trim())
            .ToList();
    }

    private static (string Content, int NextIndex)? ExtractBraceContent(string text, int startIndex)
    {
        if (startIndex >= text.Length || text[startIndex] != '{') return null;
        var depth = 0;
        var contentStart = startIndex + 1;
        for (var i = startIndex; i < text.Length; i++)
        {
            var c = text[i];
            if (c == '{') depth++;
            else if (c == '}')
            {
                depth--;
                if (depth == 0)
                    return (text.Substring(contentStart, i - contentStart), i + 1);
            }
        }
        return null;
    }
}
