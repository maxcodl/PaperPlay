; Windows installer for Teleplayer. Built by tool/build_windows_installer.ps1, which
; passes MyVersion, MyRelease, MyRedist and MyOutputDir.
;
; Installs for the current user, so it needs no admin rights. The library lives in
; AppData and isn't part of the install, so updating or uninstalling leaves it alone.

[Setup]
; Never change AppId: it's how Windows knows a new version updates this app.
AppId={{7E0F6B1A-3C52-4D8E-9A41-2B6F1C7D9E30}
AppName=Paper Play
; Held by the running app, which can be hidden in the tray. Setup asks to close it
; rather than failing to replace files that are in use.
AppMutex=Teleplayer.SingleInstance
AppVersion={#MyVersion}
AppVerName=Paper Play {#MyVersion}
AppPublisher=Paper Play
VersionInfoProductName=Paper Play
VersionInfoDescription=Paper Play Setup
PrivilegesRequired=lowest
DefaultDirName={autopf}\Teleplayer
DefaultGroupName=Teleplayer
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\teleplayer.exe
UninstallDisplayName=Paper Play
Compression=lzma2
SolidCompression=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=PaperPlay-Setup

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#MyRelease}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
; The C++ runtime the app and its DLLs need, so it also runs on a PC without it.
Source: "{#MyRedist}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyRedist}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyRedist}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

; What the earlier IExpress package left behind, so Windows doesn't list the app twice.
[InstallDelete]
Type: files; Name: "{app}\uninstall.ps1"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\Teleplayer"; ValueType: none; Flags: deletekey

[Icons]
Name: "{autoprograms}\Paper Play"; Filename: "{app}\teleplayer.exe"
Name: "{autodesktop}\Paper Play"; Filename: "{app}\teleplayer.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\teleplayer.exe"; Description: "Open Paper Play"; Flags: nowait postinstall skipifsilent
