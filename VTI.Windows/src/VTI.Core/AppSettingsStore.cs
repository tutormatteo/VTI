using System.Text.Json;
using System.Text.Json.Serialization;

namespace VTI.Core;

public sealed class AppSettingsData
{
    [JsonPropertyName("repositoryPath")]
    public string? RepositoryPath { get; set; }

    [JsonPropertyName("excludeUsedQuesitiInTestRandom")]
    public bool ExcludeUsedQuesitiInTestRandom { get; set; }
}

/// <summary>Impostazioni locali in %AppData%/VTI/settings.json</summary>
public sealed class AppSettingsStore
{
    private readonly string _filePath;

    public AppSettingsStore()
    {
        var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "VTI");
        Directory.CreateDirectory(root);
        _filePath = Path.Combine(root, "settings.json");
    }

    public AppSettingsData Load()
    {
        try
        {
            if (!File.Exists(_filePath))
                return new AppSettingsData();
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize<AppSettingsData>(json) ?? new AppSettingsData();
        }
        catch
        {
            return new AppSettingsData();
        }
    }

    public void Save(AppSettingsData data)
    {
        var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_filePath, json);
    }
}
