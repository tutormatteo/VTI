using System.Collections.ObjectModel;
using System.Windows;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using VTI.Core;

namespace VTI.App.ViewModels;

public partial class MainViewModel
{
    [ObservableProperty] private string _titoloTest = "Simulazione";

    [ObservableProperty] private DateTime? _dataTest = DateTime.Today;

    [ObservableProperty] private TestSelectionMode _testSelectionMode = TestSelectionMode.Random;

    [ObservableProperty] private bool _excludeUsedFromRandomExtractions;

    [ObservableProperty] private ObservableCollection<Quesito> _randomPreviewList = new();

    [ObservableProperty] private ObservableCollection<Quesito> _rightTestPreview = new();

    [ObservableProperty] private ObservableCollection<RandomQtyRow> _randomQtyRows = new();

    [ObservableProperty] private GeneratedDocument? _lastTestDocument;

    [ObservableProperty] private bool _testIsGenerating;

    [ObservableProperty] private string _testProcessingStatus = "Preparazione test...";

    [ObservableProperty] private EserciziarioScope _eserciziarioScope = EserciziarioScope.Completo;

    [ObservableProperty] private Materia _eserciziarioMateria = Materia.Matematica;

    [ObservableProperty] private GeneratedDocument? _lastEserciziarioDocument;

    [ObservableProperty] private bool _eserciziarioIsGenerating;

    [ObservableProperty] private string _eserciziarioProcessingStatus = "Preparazione eserciziario...";

    private readonly HashSet<Guid> _manualSelection = new();

    private readonly Dictionary<string, int> _randomRequests = new(StringComparer.Ordinal);

    public int TestUsageCount => _usageStore.UsedCount;

    public int TestPreviewCount => GetSelectedTestQuesiti().Count;

    partial void OnMaterieOrderedChanged(ObservableCollection<Materia> value)
    {
        ClampDraftMateria();
        SyncEserciziarioMateria();
    }

    partial void OnExcludeUsedFromRandomExtractionsChanged(bool value)
    {
        var d = _settingsStore.Load();
        d.ExcludeUsedQuesitiInTestRandom = value;
        _settingsStore.Save(d);
        RebuildRandomRows();
        RecomputeRandomExtracted();
        OnPropertyChanged(nameof(TestUsageCount));
    }

    partial void OnTestSelectionModeChanged(TestSelectionMode value)
    {
        if (value == TestSelectionMode.Random)
            RecomputeRandomExtracted();
        OnPropertyChanged(nameof(TestPreviewCount));
        OnPropertyChanged(nameof(IsTestRandomMode));
        OnPropertyChanged(nameof(IsTestManualMode));
        RefreshRightTestPreview();
    }

    partial void OnQuesitiChanged(ObservableCollection<Quesito> value)
    {
        RebuildRandomRows();
        if (TestSelectionMode == TestSelectionMode.Random)
            RecomputeRandomExtracted();
        OnPropertyChanged(nameof(TestPreviewCount));
        RefreshRightTestPreview();
    }

    public bool IsManualSelected(Quesito q) => _manualSelection.Contains(q.Id);

    public bool IsTestRandomMode
    {
        get => TestSelectionMode == TestSelectionMode.Random;
        set => TestSelectionMode = value ? TestSelectionMode.Random : TestSelectionMode.Manual;
    }

    public bool IsTestManualMode
    {
        get => TestSelectionMode == TestSelectionMode.Manual;
        set => TestSelectionMode = value ? TestSelectionMode.Manual : TestSelectionMode.Random;
    }

    public bool IsEserciziarioCompleto
    {
        get => EserciziarioScope == EserciziarioScope.Completo;
        set => EserciziarioScope = value ? EserciziarioScope.Completo : EserciziarioScope.MateriaSingola;
    }

    public bool IsEserciziarioMateriaSingola
    {
        get => EserciziarioScope == EserciziarioScope.MateriaSingola;
        set => EserciziarioScope = value ? EserciziarioScope.MateriaSingola : EserciziarioScope.Completo;
    }

    public bool IsBusyOverlay => TestIsGenerating || EserciziarioIsGenerating;

    partial void OnTestIsGeneratingChanged(bool value) => OnPropertyChanged(nameof(IsBusyOverlay));

    partial void OnEserciziarioIsGeneratingChanged(bool value) => OnPropertyChanged(nameof(IsBusyOverlay));

    public int[] AnswerChoices { get; } = [1, 2, 3, 4, 5];

    [RelayCommand]
    private void ToggleManualQuesito(Quesito? q)
    {
        if (q == null) return;
        if (!_manualSelection.Remove(q.Id))
            _manualSelection.Add(q.Id);
        OnPropertyChanged(nameof(TestPreviewCount));
        RefreshRightTestPreview();
    }

    [RelayCommand]
    private void IncrementRandomRow(string? key)
    {
        if (string.IsNullOrEmpty(key)) return;
        var row = RandomQtyRows.FirstOrDefault(r => r.Key == key);
        row?.Increment();
    }

    [RelayCommand]
    private void DecrementRandomRow(string? key)
    {
        if (string.IsNullOrEmpty(key)) return;
        var row = RandomQtyRows.FirstOrDefault(r => r.Key == key);
        row?.Decrement();
    }

    [RelayCommand]
    private void ClearTestForm()
    {
        TitoloTest = "Simulazione";
        DataTest = DateTime.Today;
        _manualSelection.Clear();
        _randomRequests.Clear();
        RebuildRandomRows();
        RandomPreviewList.Clear();
        LastTestDocument = null;
        StatusMessage = null;
        OnPropertyChanged(nameof(TestPreviewCount));
        RefreshRightTestPreview();
    }

    [RelayCommand]
    private void ClearTestUsageHistory()
    {
        _usageStore.RemoveAll();
        OnPropertyChanged(nameof(TestUsageCount));
        RebuildRandomRows();
        RecomputeRandomExtracted();
    }

    [RelayCommand]
    private void EstraiRandom() => RecomputeRandomExtracted();

    public void SetRandomRequest(string key, int value)
    {
        var row = RandomQtyRows.FirstOrDefault(r => r.Key == key);
        var max = row?.Eligible ?? 0;
        var clamped = Math.Clamp(value, 0, max);
        _randomRequests[key] = clamped;
        if (row != null)
            row.Requested = clamped;
        RecomputeRandomExtracted();
        OnPropertyChanged(nameof(TestPreviewCount));
    }

    [RelayCommand]
    private void GenerateTest()
    {
        var quesiti = GetSelectedTestQuesiti();
        if (quesiti.Count == 0)
        {
            StatusMessage = new UserMessage(UserMessageKind.Warning, "Seleziona almeno un quesito.");
            return;
        }
        TestIsGenerating = true;
        TestProcessingStatus = "Generazione TEX in corso...";
        var title = TitoloTest;
        var date = DataTest ?? DateTime.Today;
        var names = quesiti.Select(q => q.FileName).ToList();
        Task.Run(() =>
        {
            try
            {
                var doc = _testGen.Generate(title, date, quesiti);
                Application.Current.Dispatcher.Invoke(() =>
                {
                    LastTestDocument = doc;
                    TestIsGenerating = false;
                    if (doc.PdfPath != null)
                    {
                        _usageStore.MarkUsed(names);
                        OnPropertyChanged(nameof(TestUsageCount));
                        StatusMessage = new UserMessage(UserMessageKind.Success, "Test generato e PDF compilato correttamente.");
                    }
                    else
                    {
                        StatusMessage = new UserMessage(UserMessageKind.Warning, "TEX generato, ma il PDF non e stato compilato. Controlla il log.");
                    }
                    RebuildRandomRows();
                    RecomputeRandomExtracted();
                    OnPropertyChanged(nameof(TestPreviewCount));
                });
            }
            catch (Exception ex)
            {
                Application.Current.Dispatcher.Invoke(() =>
                {
                    TestIsGenerating = false;
                    StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
                });
            }
        });
    }

    private void RebuildRandomRows()
    {
        var rows = new ObservableCollection<RandomQtyRow>();
        foreach (var m in MaterieOrdered)
        {
            var byArg = Quesiti.Where(q => q.Materia.Equals(m)).GroupBy(q => q.Argomento);
            foreach (var g in byArg.OrderBy(x => x.Key))
            {
                var key = $"{m.RawValue}|{g.Key}";
                var total = g.Count();
                var eligible = ExcludeUsedFromRandomExtractions
                    ? g.Count(q => !_usageStore.Contains(q.FileName))
                    : total;
                var req = _randomRequests.GetValueOrDefault(key, 0);
                if (req > eligible)
                {
                    req = eligible;
                    _randomRequests[key] = req;
                }
                rows.Add(new RandomQtyRow(this, key, m, g.Key, eligible, req));
            }
        }
        RandomQtyRows = rows;
    }

    private void RecomputeRandomExtracted()
    {
        var selection = new List<Quesito>();
        foreach (var row in RandomQtyRows)
        {
            var count = _randomRequests.GetValueOrDefault(row.Key, 0);
            if (count <= 0) continue;
            var matching = Quesiti.Where(q => q.Materia.Equals(row.Materia) && q.Argomento == row.Argomento).ToList();
            var pool = ExcludeUsedFromRandomExtractions
                ? matching.Where(q => !_usageStore.Contains(q.FileName)).ToList()
                : matching;
            selection.AddRange(pool.OrderBy(_ => Guid.NewGuid()).Take(count));
        }
        selection.Sort((a, b) =>
        {
            var c = string.Compare(a.Materia.RawValue, b.Materia.RawValue, StringComparison.Ordinal);
            if (c != 0) return c;
            c = string.Compare(a.Argomento, b.Argomento, StringComparison.Ordinal);
            if (c != 0) return c;
            return string.Compare(a.FileName, b.FileName, StringComparison.Ordinal);
        });
        RandomPreviewList = new ObservableCollection<Quesito>(selection);
        OnPropertyChanged(nameof(TestPreviewCount));
        RefreshRightTestPreview();
    }

    private void RefreshRightTestPreview()
    {
        RightTestPreview = new ObservableCollection<Quesito>(GetSelectedTestQuesiti());
    }

    private List<Quesito> GetSelectedTestQuesiti()
    {
        if (TestSelectionMode == TestSelectionMode.Manual)
            return Quesiti.Where(q => _manualSelection.Contains(q.Id)).OrderBy(q => q.FileName).ToList();
        return RandomPreviewList.ToList();
    }

    partial void OnEserciziarioScopeChanged(EserciziarioScope value)
    {
        SyncEserciziarioMateria();
        OnPropertyChanged(nameof(IsEserciziarioCompleto));
        OnPropertyChanged(nameof(IsEserciziarioMateriaSingola));
    }

    private void SyncEserciziarioMateria()
    {
        if (MaterieOrdered.Count == 0) return;
        if (!MaterieOrdered.Contains(EserciziarioMateria))
            EserciziarioMateria = MaterieOrdered[0];
    }

    [RelayCommand]
    private void GenerateEserciziario()
    {
        if (Quesiti.Count == 0)
        {
            StatusMessage = new UserMessage(UserMessageKind.Warning, "Nessun quesito disponibile per questa selezione.");
            return;
        }
        EserciziarioIsGenerating = true;
        EserciziarioProcessingStatus = "Generazione eserciziario in corso...";
        var scope = EserciziarioScope;
        var mat = EserciziarioMateria;
        var list = Quesiti.ToList();
        Task.Run(() =>
        {
            try
            {
                var doc = _esercGen.Generate(scope, scope == EserciziarioScope.MateriaSingola ? mat : null, list);
                Application.Current.Dispatcher.Invoke(() =>
                {
                    LastEserciziarioDocument = doc;
                    EserciziarioIsGenerating = false;
                    if (doc.PdfPath != null)
                        StatusMessage = new UserMessage(UserMessageKind.Success, "Eserciziario generato e PDF compilato.");
                    else
                        StatusMessage = new UserMessage(UserMessageKind.Warning, "Eserciziario TEX creato, ma PDF non compilato. Controlla il log.");
                });
            }
            catch (Exception ex)
            {
                Application.Current.Dispatcher.Invoke(() =>
                {
                    EserciziarioIsGenerating = false;
                    StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
                });
            }
        });
    }
}

public partial class RandomQtyRow : ObservableObject
{
    private readonly MainViewModel _owner;

    public RandomQtyRow(MainViewModel owner, string key, Materia materia, string argomento, int eligible, int requested)
    {
        _owner = owner;
        Key = key;
        Materia = materia;
        Argomento = argomento;
        Eligible = eligible;
        Requested = requested;
    }

    public string Key { get; }
    public Materia Materia { get; }
    public string Argomento { get; }

    public int Eligible { get; }

    [ObservableProperty] private int _requested;

    public void Increment() => _owner.SetRandomRequest(Key, Requested + 1);

    public void Decrement() => _owner.SetRandomRequest(Key, Requested - 1);
}
