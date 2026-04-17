using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace VTI.Core;

public sealed record PdfCompilationResult(string? PdfPath, string Log);

public sealed class PDFCompilerService
{
    public PdfCompilationResult Compile(string texPath)
    {
        var executable = FindPdflatex();
        var outputDirectory = Path.GetDirectoryName(texPath)!;
        var texFileName = Path.GetFileName(texPath);
        var first = RunPdflatex(executable, texFileName, outputDirectory);
        var second = RunPdflatex(executable, texFileName, outputDirectory);
        var log = first + "\n\n----- SECOND PASS -----\n\n" + second;
        var pdfPath = Path.Combine(outputDirectory, Path.GetFileNameWithoutExtension(texPath) + ".pdf");
        if (!File.Exists(pdfPath))
            throw AppException.PdfCompilationFailed(log);
        return new PdfCompilationResult(pdfPath, log);
    }

    public string FindPdflatex()
    {
        foreach (var candidate in CandidatePaths())
        {
            if (File.Exists(candidate))
                return candidate;
        }
        throw AppException.PdflatexNotInstalled();
    }

    private static IEnumerable<string> CandidatePaths()
    {
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "MiKTeX", "miktex", "bin", "x64", "pdflatex.exe");
            yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "MiKTeX", "miktex", "bin", "pdflatex.exe");
            foreach (var year in new[] { "2025", "2024", "2023" })
            {
                yield return Path.Combine("C:\\texlive", year, "bin", "win32", "pdflatex.exe");
                yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "texlive", year, "bin", "win32", "pdflatex.exe");
            }
        }
        else if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            yield return "/Library/TeX/texbin/pdflatex";
            yield return "/usr/texbin/pdflatex";
            yield return "/opt/homebrew/bin/pdflatex";
            yield return "/usr/local/bin/pdflatex";
        }
        else
        {
            yield return "/usr/bin/pdflatex";
        }

        var pathEnv = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrEmpty(pathEnv)) yield break;
        var sep = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? ';' : ':';
        var name = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "pdflatex.exe" : "pdflatex";
        foreach (var dir in pathEnv.Split(sep, StringSplitOptions.RemoveEmptyEntries))
        {
            var full = Path.Combine(dir.Trim(), name);
            if (File.Exists(full))
                yield return full;
        }
    }

    private static string RunPdflatex(string executable, string texFileName, string outputDirectory)
    {
        var logPath = Path.Combine(outputDirectory, Path.GetFileNameWithoutExtension(texFileName) + ".log");
        var psi = new ProcessStartInfo
        {
            FileName = executable,
            WorkingDirectory = outputDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = false,
            RedirectStandardError = false,
            CreateNoWindow = true,
            ArgumentList =
            {
                "-interaction=nonstopmode",
                "-halt-on-error",
                "-file-line-error",
                "-output-directory",
                outputDirectory,
                texFileName
            }
        };
        using var p = Process.Start(psi) ?? throw AppException.Io("Impossibile avviare pdflatex.");
        p.WaitForExit();
        var log = ReadPdflatexLogFile(logPath);
        if (p.ExitCode != 0)
            throw AppException.PdfCompilationFailed(log);
        return log;
    }

    /// <summary>Reads the transcript written by pdfTeX to <c>basename.log</c> (UTF-8 with tolerant fallback).</summary>
    private static string ReadPdflatexLogFile(string logPath)
    {
        try
        {
            if (!File.Exists(logPath))
                return "(file .log non trovato: " + logPath + ")";
            var bytes = File.ReadAllBytes(logPath);
            return DecodeLogBytes(bytes);
        }
        catch (Exception ex)
        {
            return "Lettura log fallita: " + ex.Message;
        }
    }

    private static string DecodeLogBytes(byte[] bytes)
    {
        if (bytes.Length == 0) return "";
        try
        {
            return new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true).GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            return Encoding.Latin1.GetString(bytes);
        }
    }
}
