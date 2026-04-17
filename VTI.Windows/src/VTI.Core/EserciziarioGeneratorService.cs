namespace VTI.Core;

public sealed class EserciziarioGeneratorService
{
    private readonly RepositoryService _repository;
    private readonly LaTeXService _latex;
    private readonly PDFCompilerService _pdf;

    public EserciziarioGeneratorService(RepositoryService repository, LaTeXService latex, PDFCompilerService pdf)
    {
        _repository = repository;
        _latex = latex;
        _pdf = pdf;
    }

    public GeneratedDocument Generate(EserciziarioScope scope, Materia? materia, IReadOnlyList<Quesito> quesiti)
    {
        var destinationFolder = _repository.EserciziarioFolder();
        Directory.CreateDirectory(destinationFolder);
        var timestamp = DateTime.Now.ToString("HHmmss");
        var dateString = DateTime.Now.ToString("yyyy-MM-dd");
        var volumeName = scope == EserciziarioScope.Completo ? "Completo" : (materia?.RawValue ?? "Materia");
        var texName = $"Eserciziario_{SanitizedSegment(volumeName)}_{dateString}_{timestamp}.tex";
        var texPath = Path.Combine(destinationFolder, texName);

        var filtered = scope == EserciziarioScope.Completo
            ? quesiti
            : quesiti.Where(q => q.Materia == materia).ToList();

        var grouped = filtered.GroupBy(q => q.Materia).ToDictionary(g => g.Key, g => g.ToList());
        var orderedMaterie = scope == EserciziarioScope.Completo
            ? grouped.Keys.OrderBy(m => m).ToList()
            : materia is { } mm ? [mm] : [];

        var inPdfOrder = new List<Quesito>();
        var content = string.Join("\n\n", orderedMaterie.Select(m =>
        {
            if (!grouped.TryGetValue(m, out var items) || items.Count == 0) return null;
            var byArgomento = items.GroupBy(q => q.Argomento).OrderBy(g => g.Key, StringComparer.OrdinalIgnoreCase);
            var sectionTitle = LaTeXTextUtilities.EscapePlainText(m.SectionTitle);
            var blocks = byArgomento.Select(g =>
            {
                foreach (var q in g.OrderBy(x => x.Indice))
                    inPdfOrder.Add(q);
                var body = string.Join("\n\n", g.OrderBy(x => x.Indice).Select(q => q.LatexBlock));
                var sub = LaTeXTextUtilities.EscapePlainText(g.Key);
                return $"\\subsection{{{sub}}}\n\\begin{{enumerate}}[leftmargin=*]\n{body}\n\\end{{enumerate}}";
            });
            return $"\\section{{{sectionTitle}}}\n\n{string.Join("\n\n", blocks)}";
        }).Where(s => s != null));

        var solutions = SolutionsAppendixBuilder.BuildLongTable(inPdfOrder);

        _latex.WriteRenderedTemplate(LaTeXTemplate.Eserciziario, new Dictionary<string, string>
        {
            ["HEADER_TITLE"] = "Eserciziario",
            ["VOLUME_TITLE"] = volumeName,
            ["ACADEMIC_YEAR"] = "A.A. 2025 -- 2026",
            ["CONTENT"] = content,
            ["SOLUTIONS"] = solutions
        }, texPath);

        try
        {
            var pdf = _pdf.Compile(texPath);
            return new GeneratedDocument { TexPath = texPath, PdfPath = pdf.PdfPath, Log = pdf.Log };
        }
        catch (AppException ex)
        {
            return new GeneratedDocument { TexPath = texPath, PdfPath = null, Log = ex.Message };
        }
    }

    private static string SanitizedSegment(string value) => value.Replace(" ", "_", StringComparison.Ordinal);
}
