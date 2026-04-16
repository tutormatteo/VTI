namespace VTI.Core;

public sealed class RepositoryService
{
    private readonly AppSettingsStore _settings;

    public RepositoryService(AppSettingsStore? settings = null)
    {
        _settings = settings ?? new AppSettingsStore();
        var data = _settings.Load();
        var path = data.RepositoryPath;
        RepositoryPath = !string.IsNullOrEmpty(path) && Directory.Exists(path) ? path : null;
    }

    public string? RepositoryPath { get; private set; }

    public void SetRepository(string path)
    {
        if (!Directory.Exists(path))
            throw AppException.InvalidRepository(path);
        RepositoryPath = path;
        var data = _settings.Load();
        data.RepositoryPath = path;
        _settings.Save(data);
        EnsureRepositoryStructure();
    }

    public void ClearRepository()
    {
        RepositoryPath = null;
        var data = _settings.Load();
        data.RepositoryPath = null;
        _settings.Save(data);
    }

    public void EnsureRepositoryStructure()
    {
        var root = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        foreach (var rel in new[] { "quesiti", "test", "eserciziario" })
            Directory.CreateDirectory(Path.Combine(root, rel));
        foreach (var m in Materia.DefaultInstallMaterie)
            Directory.CreateDirectory(Path.Combine(root, "quesiti", m.RepositoryFolderName));
    }

    public IReadOnlyList<Materia> ListMaterie()
    {
        var root = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        var quesitiRoot = Path.Combine(root, "quesiti");
        if (!Directory.Exists(quesitiRoot)) return Array.Empty<Materia>();
        const string prefix = "Q - ";
        var list = new List<Materia>();
        foreach (var dir in Directory.EnumerateDirectories(quesitiRoot))
        {
            var name = Path.GetFileName(dir);
            if (!name.StartsWith(prefix, StringComparison.Ordinal)) continue;
            var raw = name[prefix.Length..];
            if (Materia.TryCreate(raw, out var m))
                list.Add(m);
        }
        list.Sort();
        return list;
    }

    public Materia AddMateria(string displayName)
    {
        if (!Materia.TryCreate(displayName, out var materia))
            throw AppException.InvalidFileNameComponent(displayName.Trim());
        EnsureRepositoryStructure();
        var folder = QuesitiFolder(materia);
        if (Directory.Exists(folder))
            throw AppException.Io($"Esiste già una cartella per la materia «{materia.RawValue}».");
        Directory.CreateDirectory(folder);
        return materia;
    }

    public string QuesitiFolder(Materia materia)
    {
        var root = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        return Path.Combine(root, "quesiti", materia.RepositoryFolderName);
    }

    public string TestFolder()
    {
        var root = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        return Path.Combine(root, "test");
    }

    public string EserciziarioFolder()
    {
        var root = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        return Path.Combine(root, "eserciziario");
    }

    public IReadOnlyList<string> AllQuestionFiles()
    {
        _ = RepositoryPath ?? throw AppException.RepositoryNotSelected();
        var files = new List<string>();
        foreach (var m in ListMaterie())
        {
            var dir = QuesitiFolder(m);
            if (!Directory.Exists(dir)) continue;
            foreach (var f in Directory.EnumerateFiles(dir, "*.txt"))
                files.Add(f);
        }
        files.Sort(StringComparer.OrdinalIgnoreCase);
        return files;
    }
}
