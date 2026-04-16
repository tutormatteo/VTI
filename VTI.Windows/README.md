# VTI per Windows (.NET 8 + WPF)

Questa cartella contiene il port **desktop Windows** dell’app macOS VTI, con le stesse funzionalità principali (repository locale, quesiti `.txt`, anteprima/compilazione PDF via `pdflatex`, generazione test ed eserciziario).

## Stack scelto

| Componente | Scelta | Motivo |
|------------|--------|--------|
| UI | **WPF** (.NET 8, `net8.0-windows`) | Integrazione nativa con cartelle, processi, anteprima PDF (WebView2), distribuzione MSI/EXE semplice |
| Logica | **VTI.Core** (`net8.0`) | Parser, file repository, template LaTeX, generatori, ricerca `pdflatex` riusabili e testabili senza UI |
| PDF in UI | **WebView2** | Visualizzazione file `file:///` senza componenti a pagamento |
| PNG da PDF | **PDFtoImage** (solo app) | Raster della prima pagina per export PNG |
| Installer | **Inno Setup** (opzionale in CI) | Icona `iconaVTI.ico`, shortcut, cartella Program Files |

## Requisiti

- Windows 10/11 x64
- [.NET 8 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/8.0) (per build self-contained non serve sul PC target se pubblichi `--self-contained`)
- **MiKTeX** o **TeX Live** con `pdflatex` sul PATH o nelle installazioni standard

## Build

```bash
cd VTI.Windows
dotnet build src/VTI.sln -c Release
```

Eseguibile: `src/VTI.App/bin/Release/net8.0-windows/win-x64/VTI.App.exe` (dipende dalla RID se usi `dotnet publish`).

## Pubblicazione e installer

Vedi [packaging/windows/README.md](../packaging/windows/README.md) e il workflow [.github/workflows/vti-windows.yml](../.github/workflows/vti-windows.yml).
