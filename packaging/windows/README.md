# Packaging Windows (VTI)

## Icona applicazione

Aggiungi il file **`iconaVTI.ico`** in questa cartella (`packaging/windows/`).  
Il progetto [VTI.App.csproj](../../VTI.Windows/src/VTI.App/VTI.App.csproj) imposta `ApplicationIcon` solo se il file esiste, così la build non fallisce senza icona.

## Build publish (da riga di comando su Windows)

```bat
cd VTI.Windows\src
dotnet publish VTI.App\VTI.App.csproj -c Release -r win-x64 --self-contained true
```

Output tipico: `VTI.App\bin\Release\net8.0-windows\win-x64\publish\`

## Installer Inno Setup

1. Installa [Inno Setup](https://jrsoftware.org/isinfo.php).
2. Copia l’output di `dotnet publish` in una cartella nota (o adatta i percorsi in `setup.iss`).
3. Compila lo script [setup.iss](setup.iss) (menu *Build → Compile*).

L’installer userà `iconaVTI.ico` come icona del setup e del collegamento, se presente.

## Distribuzione

- **GitHub Releases**: carica lo zip della cartella `publish` o il file `VTI_Setup.exe` generato da Inno Setup come asset di una release.
- Senza firma Authenticode, Windows SmartScreen può mostrare un avviso alla prima esecuzione.
