; Pemasang Razarsa untuk Windows (Inno Setup). Dibuat oleh CI; nilai dikirim lewat /D:
;   AppVersion, OutBase, SrcDir (folder hasil build Release), OutDir
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef OutBase
  #define OutBase "razarsa-setup"
#endif
#ifndef SrcDir
  #error SrcDir harus diisi
#endif
#ifndef OutDir
  #define OutDir "."
#endif

[Setup]
AppId={{6B1F0C52-3E8D-4F7A-9A57-52415A525341}
AppName=Razarsa
AppVersion={#AppVersion}
AppPublisher=Razarsa
DefaultDirName={autopf}\Razarsa
DefaultGroupName=Razarsa
DisableProgramGroupPage=yes
; Pasang untuk pengguna saat ini tanpa hak admin; pengguna boleh memilih untuk semua pengguna.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutDir}
OutputBaseFilename={#OutBase}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\razarsa.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Buat pintasan di Desktop"; GroupDescription: "Pintasan:"; Flags: unchecked

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
; AppUserModelID sama dengan Notif.windowsAumid (lib/core/notifications.dart) supaya notifikasi toast
; tampil atas nama Razarsa dan bisa diklik untuk membuka aplikasi.
Name: "{autoprograms}\Razarsa"; Filename: "{app}\razarsa.exe"; AppUserModelID: "Razarsa.Razarsa.App"
Name: "{autodesktop}\Razarsa"; Filename: "{app}\razarsa.exe"; Tasks: desktopicon; AppUserModelID: "Razarsa.Razarsa.App"

[Run]
Filename: "{app}\razarsa.exe"; Description: "Buka Razarsa"; Flags: nowait postinstall skipifsilent
