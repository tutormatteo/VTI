namespace VTI.Core;

public sealed class AppException : Exception
{
    public AppException(string message) : base(message) { }
    public AppException(string message, Exception inner) : base(message, inner) { }

    public static AppException RepositoryNotSelected() =>
        new("Cartella di lavoro non selezionata. Sceglila dalla scheda Home.");

    public static AppException InvalidRepository(string path) =>
        new($"La cartella selezionata non e valida: {path}");

    public static AppException MalformedFileName(string name) =>
        new($"Il nome file non rispetta il formato atteso: {name}");

    public static AppException MalformedQuestionFile(string fileName) =>
        new($"Il file quesito non e leggibile o non contiene una domanda valida: {fileName}");

    public static AppException TemplateNotFound(string name) =>
        new($"Template LaTeX non trovato: {name}");

    public static AppException PdflatexNotInstalled() =>
        new("pdflatex non e installato o non e raggiungibile. Installa MiKTeX o TeX Live e assicurati che pdflatex sia nel PATH.");

    public static AppException PdfCompilationFailed(string log) =>
        new($"Compilazione PDF fallita.\n{log}");

    public static AppException InvalidFileNameComponent(string value) =>
        new($"Il testo '{value}' contiene caratteri non validi per il nome file.");

    public static AppException Io(string message) => new(message);
}
