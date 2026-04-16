using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Win32;
using VTI.Core;
using WinForms = System.Windows.Forms;

namespace VTI.App.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private readonly AppSettingsStore _settingsStore = new();
    private readonly RepositoryService _repository;
    private readonly QuesitoParserService _parser = new();
    private readonly QuesitoWriterService _writer;
    private readonly LaTeXService _latex = new();
    private readonly PDFCompilerService _pdf = new();
    private readonly TestGeneratorService _testGen;
    private readonly EserciziarioGeneratorService _esercGen;
    private readonly QuesitoPreviewService _previewSvc;
    private readonly TestQuesitoUsageStore _usageStore = new();
    private readonly DispatcherTimer _previewDebounce;
    private CancellationTokenSource? _previewCts;

    public MainViewModel()
    {
        _repository = new RepositoryService(_settingsStore);
        _writer = new QuesitoWriterService(_repository);
        _testGen = new TestGeneratorService(_repository, _latex, _pdf);
        _esercGen = new EserciziarioGeneratorService(_repository, _latex, _pdf);
        _previewSvc = new QuesitoPreviewService(_latex, _pdf);

        _previewDebounce = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(550) };
        _previewDebounce.Tick += (_, _) =>
        {
            _previewDebounce.Stop();
            _ = RunDraftPreviewAsync();
        };

        Draft.PropertyChanged += (_, _) => SchedulePreviewDebounce();
        Draft.Opzioni.CollectionChanged += (_, _) => SchedulePreviewDebounce();

        var prefs = _settingsStore.Load();
        ExcludeUsedFromRandomExtractions = prefs.ExcludeUsedQuesitiInTestRandom;

        LoadQuesiti();
    }

    public NewQuesitoDraft Draft { get; } = new();

    [ObservableProperty] private SidebarSection _selectedSection = SidebarSection.Home;

    [ObservableProperty] private UserMessage? _statusMessage;

    [ObservableProperty] private string _newMateriaName = "";

    [ObservableProperty] private ObservableCollection<Quesito> _quesiti = new();

    [ObservableProperty] private ObservableCollection<Materia> _materieOrdered = new();

    [ObservableProperty] private bool _isLoadingQuesiti;

    [ObservableProperty] private Quesito? _selectedRepositoryQuesito;

    [ObservableProperty] private QuesitiInputMode _quesitiInputMode = QuesitiInputMode.Create;

    [ObservableProperty] private Materia _importMateria = Materia.Matematica;

    [ObservableProperty] private string _importArgomento = "";

    [ObservableProperty] private string _importTitolo = "";

    [ObservableProperty] private string? _importFilePath;

    [ObservableProperty] private string? _previewPdfPath;

    [ObservableProperty] private bool _previewLoading;

    [ObservableProperty] private string? _previewError;

    public string? RepositoryPath => _repository.RepositoryPath;

    partial void OnQuesitiInputModeChanged(QuesitiInputMode value)
    {
        OnPropertyChanged(nameof(IsCreateQuesitiMode));
        OnPropertyChanged(nameof(IsImportQuesitiMode));
        if (value != QuesitiInputMode.Create)
        {
            PreviewPdfPath = null;
            PreviewError = null;
            PreviewLoading = false;
        }
    }

    public bool IsCreateQuesitiMode
    {
        get => QuesitiInputMode == QuesitiInputMode.Create;
        set
        {
            QuesitiInputMode = value ? QuesitiInputMode.Create : QuesitiInputMode.ImportTxt;
            OnPropertyChanged();
        }
    }

    public bool IsImportQuesitiMode
    {
        get => QuesitiInputMode == QuesitiInputMode.ImportTxt;
        set
        {
            if (value) QuesitiInputMode = QuesitiInputMode.ImportTxt;
            OnPropertyChanged();
        }
    }

    partial void OnSelectedRepositoryQuesitoChanged(Quesito? value)
    {
        if (value != null)
            _ = RunRepositoryPreviewAsync();
    }

    [RelayCommand]
    private void ReloadQuesiti() => LoadQuesiti();

    [RelayCommand]
    private async Task RefreshRepositoryPreview() => await RunRepositoryPreviewAsync();

    [RelayCommand]
    private void ChooseRepository()
    {
        using var dlg = new WinForms.FolderBrowserDialog
        {
            Description = "Seleziona la cartella di lavoro (quesiti, test, eserciziario).",
            UseDescriptionForTitle = true
        };
        if (dlg.ShowDialog() != WinForms.DialogResult.OK) return;
        try
        {
            _repository.SetRepository(dlg.SelectedPath);
            OnPropertyChanged(nameof(RepositoryPath));
            StatusMessage = new UserMessage(UserMessageKind.Success, $"Repository impostata in {dlg.SelectedPath}");
            LoadQuesiti();
        }
        catch (Exception ex)
        {
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
    }

    [RelayCommand]
    private void AddMateria()
    {
        if (string.IsNullOrWhiteSpace(NewMateriaName) || RepositoryPath == null)
            return;
        try
        {
            _repository.AddMateria(NewMateriaName.Trim());
            NewMateriaName = "";
            OnPropertyChanged(nameof(RepositoryPath));
            StatusMessage = new UserMessage(UserMessageKind.Success, "Materia aggiunta: cartella quesiti creata.");
            LoadQuesiti();
        }
        catch (Exception ex)
        {
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
    }

    public void LoadQuesiti()
    {
        if (_repository.RepositoryPath == null)
        {
            Quesiti.Clear();
            MaterieOrdered.Clear();
            RebuildRandomRows();
            RecomputeRandomExtracted();
            return;
        }
        IsLoadingQuesiti = true;
        try
        {
            _repository.EnsureRepositoryStructure();
            var materie = _repository.ListMaterie();
            MaterieOrdered = new ObservableCollection<Materia>(materie);
            ClampDraftMateria();
            var list = new List<Quesito>();
            foreach (var path in _repository.AllQuestionFiles())
            {
                try
                {
                    list.Add(_parser.ParseFile(path));
                }
                catch
                {
                    /* skip malformed */
                }
            }
            Quesiti = new ObservableCollection<Quesito>(list);
            if (StatusMessage?.Kind == UserMessageKind.Error)
                StatusMessage = null;
        }
        catch (Exception ex)
        {
            Quesiti.Clear();
            MaterieOrdered.Clear();
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
        finally
        {
            IsLoadingQuesiti = false;
        }
        RebuildRandomRows();
        RecomputeRandomExtracted();
    }

    private void ClampDraftMateria()
    {
        if (MaterieOrdered.Count == 0) return;
        if (!MaterieOrdered.Contains(Draft.Materia))
            Draft.Materia = MaterieOrdered[0];
        if (!MaterieOrdered.Contains(ImportMateria))
            ImportMateria = MaterieOrdered[0];
    }

    [RelayCommand]
    private void SaveDraft()
    {
        try
        {
            var path = _writer.Save(Draft);
            StatusMessage = new UserMessage(UserMessageKind.Success, $"Quesito salvato: {Path.GetFileName(path)}");
            Draft.Reset(MaterieOrdered.FirstOrDefault());
            LoadQuesiti();
        }
        catch (Exception ex)
        {
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
    }

    [RelayCommand]
    private void PickImportTxt()
    {
        var dlg = new OpenFileDialog { Filter = "Testo|*.txt", Title = "Seleziona file TXT del quesito" };
        if (dlg.ShowDialog() == true)
            ImportFilePath = dlg.FileName;
    }

    [RelayCommand]
    private void ImportTxt()
    {
        if (string.IsNullOrEmpty(ImportFilePath))
        {
            StatusMessage = new UserMessage(UserMessageKind.Warning, "Seleziona prima un file TXT da importare.");
            return;
        }
        try
        {
            var saved = _writer.ImportTxt(ImportFilePath, ImportMateria, ImportArgomento, ImportTitolo);
            StatusMessage = new UserMessage(UserMessageKind.Success, $"Import completato: {Path.GetFileName(saved)}");
            ImportArgomento = "";
            ImportTitolo = "";
            ImportFilePath = null;
            LoadQuesiti();
        }
        catch (Exception ex)
        {
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
    }

    [RelayCommand]
    private void ClearQuesitiPlus()
    {
        Draft.Reset(MaterieOrdered.FirstOrDefault());
        ImportMateria = MaterieOrdered.FirstOrDefault();
        ImportArgomento = "";
        ImportTitolo = "";
        ImportFilePath = null;
        QuesitiInputMode = QuesitiInputMode.Create;
        PreviewPdfPath = null;
        PreviewError = null;
        StatusMessage = null;
    }

    public void SchedulePreviewDebounce()
    {
        if (QuesitiInputMode != QuesitiInputMode.Create) return;
        if (_writer.LatexBlockForPreview(Draft) == null)
        {
            PreviewPdfPath = null;
            PreviewError = null;
            PreviewLoading = false;
            return;
        }
        _previewDebounce.Stop();
        _previewDebounce.Start();
    }

    [RelayCommand]
    private async Task RunDraftPreviewNow()
    {
        if (_writer.LatexBlockForPreview(Draft) == null)
        {
            PreviewPdfPath = null;
            PreviewError = "Compila argomento, titolo, testo domanda e tutte e 5 le opzioni per generare l'anteprima.";
            PreviewLoading = false;
            return;
        }
        await RunDraftPreviewAsync();
    }

    private async Task RunDraftPreviewAsync()
    {
        var block = _writer.LatexBlockForPreview(Draft);
        if (block == null) return;
        _previewCts?.Cancel();
        var cts = new CancellationTokenSource();
        _previewCts = cts;
        PreviewLoading = true;
        PreviewError = null;
        try
        {
            var url = await Task.Run(() => _previewSvc.CompilePdf(block), cts.Token).ConfigureAwait(true);
            if (!cts.IsCancellationRequested)
                PreviewPdfPath = url;
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            if (!cts.IsCancellationRequested)
            {
                PreviewPdfPath = null;
                PreviewError = ex.Message;
            }
        }
        finally
        {
            if (!cts.IsCancellationRequested)
                PreviewLoading = false;
        }
    }

    private async Task RunRepositoryPreviewAsync()
    {
        var q = SelectedRepositoryQuesito;
        if (q == null)
        {
            PreviewPdfPath = null;
            PreviewError = null;
            PreviewLoading = false;
            return;
        }
        PreviewLoading = true;
        PreviewError = null;
        try
        {
            var url = await Task.Run(() => _previewSvc.CompilePdf(q.LatexBlock)).ConfigureAwait(true);
            PreviewPdfPath = url;
        }
        catch (Exception ex)
        {
            PreviewPdfPath = null;
            PreviewError = ex.Message;
        }
        finally
        {
            PreviewLoading = false;
        }
    }

    [RelayCommand]
    private void ExportPreviewPng()
    {
        if (string.IsNullOrEmpty(PreviewPdfPath))
        {
            StatusMessage = new UserMessage(UserMessageKind.Warning, "Genera prima l'anteprima PDF.");
            return;
        }
        var suggested = SelectedRepositoryQuesito != null
            ? Path.ChangeExtension(SelectedRepositoryQuesito.FileName, ".png")
            : "Anteprima_quesito.png";
        var dlg = new SaveFileDialog { Filter = "PNG|*.png", FileName = suggested };
        if (dlg.ShowDialog() != true) return;
        try
        {
            PDFtoImage.Conversion.SavePng(PreviewPdfPath, dlg.FileName, page: 0);
            StatusMessage = new UserMessage(UserMessageKind.Success, $"PNG salvato: {Path.GetFileName(dlg.FileName)}");
        }
        catch (Exception ex)
        {
            StatusMessage = new UserMessage(UserMessageKind.Error, ex.Message);
        }
    }

    [RelayCommand]
    private void OpenPath(string? path)
    {
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;
        Process.Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
    }

    [RelayCommand]
    private void ShowInExplorer(string? path)
    {
        if (string.IsNullOrEmpty(path)) return;
        Process.Start("explorer.exe", $"/select,\"{path}\"");
    }

    public IEnumerable<(Materia Materia, string Argomento, IReadOnlyList<Quesito> Files)> GroupedRepositoryTree()
    {
        foreach (var m in MaterieOrdered)
        {
            var byArg = Quesiti.Where(q => q.Materia.Equals(m)).GroupBy(q => q.Argomento).OrderBy(g => g.Key);
            foreach (var g in byArg)
                yield return (m, g.Key, g.OrderBy(q => q.FileName).ToList());
        }
    }
}
