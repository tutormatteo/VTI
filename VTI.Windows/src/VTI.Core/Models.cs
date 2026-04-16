using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace VTI.Core;

public readonly record struct Materia(string RawValue) : IComparable<Materia>
{
    public string RepositoryFolderName => $"Q - {RawValue}";
    public string SectionTitle => RawValue;
    public int CompareTo(Materia other) => string.Compare(RawValue, other.RawValue, StringComparison.OrdinalIgnoreCase);

    public static bool TryCreate(string rawValue, out Materia materia)
    {
        var t = rawValue.Trim();
        if (string.IsNullOrEmpty(t) || t.Length > 120)
        {
            materia = default;
            return false;
        }
        const string invalid = "/:\\?%*|\"<>\n\r";
        if (t.IndexOfAny(invalid.ToCharArray()) >= 0)
        {
            materia = default;
            return false;
        }
        materia = new Materia(t);
        return true;
    }

    public static readonly Materia Matematica = new("Matematica");
    public static readonly Materia Logica = new("Logica");
    public static readonly Materia Scienze = new("Scienze");

    public static IReadOnlyList<Materia> DefaultInstallMaterie { get; } = [Matematica, Logica, Scienze];
}

public enum SidebarSection
{
    Home,
    QuesitiRepository,
    QuesitiPlus,
    Test,
    Eserciziario
}

public sealed class Quesito
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required Materia Materia { get; init; }
    public required string Argomento { get; init; }
    public required string Titolo { get; init; }
    public int Indice { get; init; }
    public required string FileName { get; init; }
    public required string RawText { get; init; }
    public required string DomandaLatex { get; init; }
    public required IReadOnlyList<string> Opzioni { get; init; }
    public int? RispostaCorretta { get; init; }
    public required string UrlFile { get; init; }
    public required string LatexBlock { get; init; }
}

public sealed class NewQuesitoDraft : INotifyPropertyChanged
{
    private Materia _materia = Materia.Matematica;
    private string _argomento = "";
    private string _titolo = "";
    private string _testoDomanda = "";
    private int _rispostaCorretta = 1;

    public Materia Materia
    {
        get => _materia;
        set { if (value.Equals(_materia)) return; _materia = value; OnPropertyChanged(); }
    }

    public string Argomento
    {
        get => _argomento;
        set { if (value == _argomento) return; _argomento = value; OnPropertyChanged(); }
    }

    public string Titolo
    {
        get => _titolo;
        set { if (value == _titolo) return; _titolo = value; OnPropertyChanged(); }
    }

    public string TestoDomanda
    {
        get => _testoDomanda;
        set { if (value == _testoDomanda) return; _testoDomanda = value; OnPropertyChanged(); }
    }

    public ObservableCollection<string> Opzioni { get; } = new() { "", "", "", "", "" };

    public int RispostaCorretta
    {
        get => _rispostaCorretta;
        set { if (value == _rispostaCorretta) return; _rispostaCorretta = value; OnPropertyChanged(); }
    }

    public void Reset(Materia defaultMateria)
    {
        Materia = string.IsNullOrEmpty(defaultMateria.RawValue) ? Materia.Matematica : defaultMateria;
        Argomento = "";
        Titolo = "";
        TestoDomanda = "";
        RispostaCorretta = 1;
        for (var i = 0; i < 5; i++)
            Opzioni[i] = "";
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public enum QuesitiInputMode { Create, ImportTxt }

public enum TestSelectionMode { Random, Manual }

public readonly record struct ArgomentoGroupKey(Materia Materia, string Argomento);

public enum EserciziarioScope { Completo, MateriaSingola }

public sealed class GeneratedDocument
{
    public required string TexPath { get; init; }
    public string? PdfPath { get; init; }
    public required string Log { get; init; }
}

public enum UserMessageKind { Info, Success, Warning, Error }

public sealed class UserMessage
{
    public UserMessageKind Kind { get; }
    public string Text { get; }
    public UserMessage(UserMessageKind kind, string text)
    {
        Kind = kind;
        Text = text;
    }
}
