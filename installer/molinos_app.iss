; ============================================
; Inno Setup Script - Industrial de Molinos
; ============================================
; Descarga Inno Setup: https://jrsoftware.org/isdl.php
; Para compilar: abrir este archivo con Inno Setup y dar click en "Compile"
;
; IMPORTANTE: Primero ejecuta  flutter build windows --release
;             antes de compilar este script.

#define MyAppName "Industrial de Molinos"
#define MyAppVersion "1.0.4"
#define MyAppPublisher "Industrial de Molinos"
#define MyAppExeName "molinos_app.exe"
#define MyAppDescription "Sistema de Gestion Contable para PYME"

[Setup]
; Identificador unico de la app (NO cambiar despues del primer release)
AppId={{E7A3B5C1-4D2F-4A8E-9B6C-1F3E5D7A9B2C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/industrial-de-molinos
AppSupportURL=https://github.com/industrial-de-molinos
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Ruta de salida del instalador
OutputDir=..\build\installer
OutputBaseFilename=MolinosApp_Setup_{#MyAppVersion}
; Icono del instalador
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Compresion maxima
Compression=lzma2/ultra64
SolidCompression=yes
; Requiere privilegios de admin para instalar en Program Files
PrivilegesRequired=admin
; Estilo visual moderno
WizardStyle=modern
; Info de desinstalacion
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; Permitir que el usuario elija directorio
AllowNoIcons=yes
; Licencia (opcional, descomenta si tienes una)
; LicenseFile=..\LICENSE

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el &Escritorio"; GroupDescription: "Accesos directos:"; Flags: checkedonce

[Files]
; Copiar TODO el contenido del build de Flutter
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en Menu Inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "{#MyAppDescription}"
; Acceso directo en Escritorio
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "{#MyAppDescription}"
; Opcion de desinstalar en Menu Inicio
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
; Opcion para ejecutar la app al terminar la instalacion
Filename: "{app}\{#MyAppExeName}"; Description: "Iniciar {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
// Cerrar la app si esta corriendo antes de actualizar
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Intentar cerrar la app si esta corriendo
  Exec('taskkill', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
