; Inno Setup script for VTI (adjust #define PublishDir after dotnet publish)
#define MyAppName "VTI"
#define MyAppVersion "1.0.0"
#define MyAppExeName "VTI.exe"
#ifndef PublishDir
  #define PublishDir "..\..\VTI.Windows\src\VTI.App\bin\Release\net8.0-windows\win-x64\publish"
#endif

[Setup]
AppId={{A8F3C961-4E2B-4C9D-9F1E-123456789ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\artifacts
OutputBaseFilename=VTI_Setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
DisableProgramGroupPage=yes

#if FileExists(AddBackslash(SourcePath) + "iconaVTI.ico")
SetupIconFile=iconaVTI.ico
#endif

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Avvia {#MyAppName}"; Flags: nowait postinstall skipifsilent
