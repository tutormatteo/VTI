namespace VTI.Core;

public sealed class QuesitoPreviewService
{
    private readonly LaTeXService _latex;
    private readonly PDFCompilerService _pdf;

    public QuesitoPreviewService(LaTeXService latex, PDFCompilerService pdf)
    {
        _latex = latex;
        _pdf = pdf;
    }

    public string CompilePdf(string latexBody)
    {
        var dir = Path.Combine(Path.GetTempPath(), "VTI-QuesitoPreview-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        var texPath = Path.Combine(dir, "QuesitoPreview.tex");
        _latex.WriteRenderedTemplate(LaTeXTemplate.QuesitoPreview, new Dictionary<string, string>
        {
            ["BODY"] = latexBody
        }, texPath);
        var result = _pdf.Compile(texPath);
        if (string.IsNullOrEmpty(result.PdfPath) || !File.Exists(result.PdfPath))
            throw AppException.PdfCompilationFailed(result.Log);
        return result.PdfPath;
    }
}
