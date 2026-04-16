namespace VTI.Core;

public sealed class QuesitoWriterService
{
    private readonly RepositoryService _repository;

    public QuesitoWriterService(RepositoryService repository) => _repository = repository;

    public string Save(NewQuesitoDraft draft)
    {
        var materia = draft.Materia;
        var argomento = SanitizedNameComponent(draft.Argomento);
        var titolo = SanitizedNameComponent(draft.Titolo);
        var testoDomanda = draft.TestoDomanda.Trim();
        var opzioni = draft.Opzioni.Select(o => o.Trim()).ToList();
        if (string.IsNullOrEmpty(argomento) || string.IsNullOrEmpty(titolo) || string.IsNullOrEmpty(testoDomanda))
            throw AppException.Io("Completa materia, argomento, titolo e testo domanda.");
        if (opzioni.Count != 5 || opzioni.Any(string.IsNullOrEmpty))
            throw AppException.Io("Il quesito deve avere esattamente 5 opzioni, tutte compilate.");
        var filePath = BuildOutputFilePath(materia, argomento, titolo);
        var content = MakeContent(testoDomanda, opzioni, draft.RispostaCorretta);
        File.WriteAllText(filePath, content);
        return filePath;
    }

    public string ImportTxt(string sourcePath, Materia materia, string argomento, string titolo)
    {
        var cleanedArgomento = SanitizedNameComponent(argomento);
        var cleanedTitolo = SanitizedNameComponent(titolo);
        if (string.IsNullOrEmpty(cleanedArgomento) || string.IsNullOrEmpty(cleanedTitolo))
            throw AppException.Io("Inserisci materia, argomento e titolo per l'import.");
        var raw = File.ReadAllText(sourcePath);
        if (string.IsNullOrWhiteSpace(raw))
            throw AppException.Io("Il file TXT selezionato e vuoto.");
        var filePath = BuildOutputFilePath(materia, cleanedArgomento, cleanedTitolo);
        File.WriteAllText(filePath, raw);
        return filePath;
    }

    public static string MakeContent(string question, IReadOnlyList<string> options, int correctAnswer)
    {
        var optionLines = string.Join("\n", options.Select(o => $"    \\item {o}"));
        return $"""
            \itemdomanda{{{question}}}{{
            {optionLines}
            }}

            Risposta Corretta: {correctAnswer}
            """;
    }

    public string? LatexBlockForPreview(NewQuesitoDraft draft)
    {
        var argomento = draft.Argomento.Trim();
        var titolo = draft.Titolo.Trim();
        var testoDomanda = draft.TestoDomanda.Trim();
        var opzioni = draft.Opzioni.Select(o => o.Trim()).ToList();
        if (string.IsNullOrEmpty(argomento) || string.IsNullOrEmpty(titolo) || string.IsNullOrEmpty(testoDomanda)
            || opzioni.Count != 5 || opzioni.Any(string.IsNullOrEmpty))
            return null;
        var full = MakeContent(testoDomanda, opzioni, draft.RispostaCorretta);
        return StripRispostaLine(full);
    }

    private static string StripRispostaLine(string text) =>
        string.Join("\n", text.Split('\n')
            .Where(line => !line.Trim().StartsWith("Risposta Corretta:", StringComparison.OrdinalIgnoreCase)))
            .Trim();

    private string BuildOutputFilePath(Materia materia, string argomento, string titolo)
    {
        var folder = _repository.QuesitiFolder(materia);
        var nextIndex = NextAvailableIndex(materia, argomento, titolo, folder);
        var fileName = $"{materia.RawValue} - {argomento} - {titolo} #{nextIndex}.txt";
        return Path.Combine(folder, fileName);
    }

    private static int NextAvailableIndex(Materia materia, string argomento, string titolo, string folder)
    {
        var prefix = $"{materia.RawValue} - {argomento} - {titolo} #";
        if (!Directory.Exists(folder)) return 0;
        var max = -1;
        foreach (var f in Directory.EnumerateFiles(folder, "*.txt"))
        {
            var name = Path.GetFileName(f);
            if (!name.StartsWith(prefix, StringComparison.Ordinal) || !name.EndsWith(".txt", StringComparison.Ordinal))
                continue;
            var mid = name.Substring(prefix.Length);
            mid = mid[..mid.IndexOf('.')];
            if (int.TryParse(mid, out var n))
                max = Math.Max(max, n);
        }
        return max + 1;
    }

    private static string SanitizedNameComponent(string value)
    {
        var trimmed = value.Trim();
        const string invalid = "/:\\?%*|\"<>";
        if (trimmed.IndexOfAny(invalid.ToCharArray()) >= 0)
            throw AppException.InvalidFileNameComponent(value);
        return trimmed.Replace("\n", " ", StringComparison.Ordinal);
    }
}
