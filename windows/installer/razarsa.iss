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

[Code]
// Saat dihapus: tawarkan menghapus data aplikasi juga (transaksi, catatan, pengaturan, foto profil),
// yang tersimpan di %APPDATA%\Razarsa\Razarsa. Tanpa ini, memasang ulang memunculkan data lama.
// Penghapusan diam-diam (/VERYSILENT, mis. tes CI) tidak menyentuh data.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  DataDir := ExpandConstant('{userappdata}\Razarsa\Razarsa');
  if UninstallSilent or not DirExists(DataDir) then Exit;
  if MsgBox('Hapus juga semua data Razarsa di komputer ini?' + #13#10#13#10 +
            'Transaksi, target, tugas, catatan, pengaturan, dan foto profil akan hilang permanen. ' +
            'Pilih "No" kalau ingin memakainya lagi saat memasang ulang.',
            mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
  begin
    DelTree(DataDir, True, True, True);
    RemoveDir(ExpandConstant('{userappdata}\Razarsa'));
  end;
end;
