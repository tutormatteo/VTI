using System.Text.RegularExpressions;

namespace VTI.Core;

public sealed class TestGeneratorService
{
    private readonly RepositoryService _repository;
    private readonly LaTeXService _latex;
    private readonly PDFCompilerService _pdf;

    public TestGeneratorService(RepositoryService repository, LaTeXService latex, PDFCompilerService pdf)
    {
        _repository = repository;
        _latex = latex;
        _pdf = pdf;
    }

    public GeneratedDocument Generate(string title, DateTime date, IReadOnlyList<Quesito> quesiti)
    {
        var destinationFolder = _repository.TestFolder();
        Directory.CreateDirectory(destinationFolder);
        var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
        var safeTitle = SanitizedSegment(string.IsNullOrWhiteSpace(title) ? "Test" : title);
        var dateString = date.ToString("yyyy-MM-dd");
        var safeDate = SanitizedSegment(dateString);
        var fileName = $"Test_{safeTitle}_{safeDate}_{timestamp}.tex";
        var texPath = Path.Combine(destinationFolder, fileName);
        var list = quesiti.ToList();
        var body = string.Join("\n\n", list.Select(q => q.LatexBlock));
        var solutions = SolutionsAppendixBuilder.BuildLongTable(list);
        var displayDate = date.ToString("d", new System.Globalization.CultureInfo("it-IT"));
        _latex.WriteRenderedTemplate(LaTeXTemplate.Test, new Dictionary<string, string>
        {
            ["TITLE"] = string.IsNullOrWhiteSpace(title) ? "Test personalizzato" : title,
            ["DATE"] = displayDate,
            ["BODY"] = body,
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

    private static string SanitizedSegment(string value)
    {
        var s = Regex.Replace(value.Trim().Replace(' ', '_'), @"[^a-zA-Z0-9]+", "_");
        s = s.Trim('_');
        return string.IsNullOrEmpty(s) ? "Test" : s;
    }
}
