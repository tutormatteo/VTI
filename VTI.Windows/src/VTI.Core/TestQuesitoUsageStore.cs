using System.Text.Json;

namespace VTI.Core;

/// <summary>Storico nomi file quesiti usati in test con PDF generato (come su macOS).</summary>
public sealed class TestQuesitoUsageStore
{
    private const string FileName = "test_used_quesiti_filenames.json";
    private readonly string _filePath;
    private readonly HashSet<string> _used = new(StringComparer.OrdinalIgnoreCase);

    public TestQuesitoUsageStore()
    {
        var baseDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "VTI");
        Directory.CreateDirectory(baseDir);
        _filePath = Path.Combine(baseDir, FileName);
        Load();
    }

    public int UsedCount => _used.Count;

    public bool Contains(string fileName) => _used.Contains(fileName);

    public void MarkUsed(IEnumerable<string> fileNames)
    {
        foreach (var n in fileNames)
            if (!string.IsNullOrEmpty(n))
                _used.Add(n);
        Save();
    }

    public void RemoveAll()
    {
        _used.Clear();
        Save();
    }

    private void Load()
    {
        try
        {
            if (!File.Exists(_filePath)) return;
            var json = File.ReadAllText(_filePath);
            var list = JsonSerializer.Deserialize<List<string>>(json);
            if (list == null) return;
            foreach (var s in list)
                _used.Add(s);
        }
        catch { /* ignore */ }
    }

    private void Save()
    {
        try
        {
            var list = _used.OrderBy(s => s, StringComparer.OrdinalIgnoreCase).ToList();
            File.WriteAllText(_filePath, JsonSerializer.Serialize(list));
        }
        catch { /* ignore */ }
    }
}
