; Script para Inno Setup
; ATENÇÃO: Este script espera que a compilação do Flutter (build) esteja em build\windows\runner\Release

[Setup]
; Informações do App
AppName=ThomasMedSoft
AppVersion=1.0.0
AppPublisher=ThomasMedSoft (Seu Nome/Empresa)
AppWebSite=https://[SEU_SITE_VERCEL_AQUI]
DefaultDirName={autopf}\ThomasMedSoft
DefaultGroupName=ThomasMedSoft
AllowNoIcons=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Onde o instalador .exe será guardado
OutputDir=build\windows\installer
; O nome do seu instalador
OutputBaseFilename=ThomasMedSoft-Instalador-v1.0.0
; O ícone do instalador (o mesmo do app)
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkablealone

[Files]
; Esta linha é a mais importante:
; Pega TUDO da pasta de compilação do Flutter e coloca na pasta de instalação.
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ThomasMedSoft"; Filename: "{app}\thomas_med_soft.exe"
Name: "{autodesktop}\ThomasMedSoft"; Filename: "{app}\thomas_med_soft.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\thomas_med_soft.exe"; Description: "{cm:LaunchProgram,ThomasMedSoft}"; Flags: nowait postinstall skipifsilent
