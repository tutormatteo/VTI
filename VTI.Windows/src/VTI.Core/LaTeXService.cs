using System.Reflection;

namespace VTI.Core;

public enum LaTeXTemplate
{
    Test,
    Eserciziario,
    QuesitoPreview
}

public sealed class LaTeXService
{
    private static string TemplatesDirectory()
    {
        var loc = Assembly.GetExecutingAssembly().Location;
        var dir = string.IsNullOrEmpty(loc) ? AppContext.BaseDirectory : Path.GetDirectoryName(loc)!;
        return Path.Combine(dir, "Templates");
    }

    public string Render(LaTeXTemplate template, IReadOnlyDictionary<string, string> placeholders)
    {
        var name = template switch
        {
            LaTeXTemplate.Test => "TestTemplate",
            LaTeXTemplate.Eserciziario => "EserciziarioTemplate",
            LaTeXTemplate.QuesitoPreview => "QuesitoPreviewTemplate",
            _ => throw new ArgumentOutOfRangeException(nameof(template))
        };
        var text = LoadTemplate(name);
        foreach (var (key, value) in placeholders)
            text = text.Replace("{{" + key + "}}", value, StringComparison.Ordinal);
        return text;
    }

    public string WriteRenderedTemplate(LaTeXTemplate template, IReadOnlyDictionary<string, string> placeholders, string destinationPath)
    {
        var output = Render(template, placeholders);
        File.WriteAllText(destinationPath, output);
        return destinationPath;
    }

    private static string LoadTemplate(string name)
    {
        var path = Path.Combine(TemplatesDirectory(), name + ".tex");
        if (File.Exists(path))
            return File.ReadAllText(path);
        throw AppException.TemplateNotFound($"{name}.tex");
    }
}
