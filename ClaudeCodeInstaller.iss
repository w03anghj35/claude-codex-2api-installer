; ============================================================================
; Claude Code 安装程序 - Inno Setup 脚本
; 面向中国用户的一键安装工具
;
; 编译方法:
;   1. 下载并安装 Inno Setup: https://jrsoftware.org/isinfo.php
;   2. 打开本文件，点击 Build -> Compile
;   3. 生成的安装包位于 Output 目录
; ============================================================================

#define AppName "Claude / Codex 安装助手"
#define AppVersion "1.0.0"
#define AppPublisher "Claude Code Community"
#define AppURL "https://github.com/anthropics/claude-code"
#define TokenURL "https://2api.cloud/console/token"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\ClaudeCode
DefaultGroupName=Claude Code
DisableProgramGroupPage=yes
OutputBaseFilename=ClaudeCode-Setup-v{#AppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
ShowLanguageDialog=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Messages]
chinesesimplified.WelcomeLabel1=欢迎使用 Claude / Codex 安装助手
chinesesimplified.WelcomeLabel2=本程序将帮助您一键安装和配置 Claude Code 或 Codex，并引导配置 2api。%n%n令牌获取地址：{#TokenURL}%n%n建议关闭其他应用程序后再继续。
chinesesimplified.FinishedHeadingLabel=安装完成
chinesesimplified.FinishedLabel=Claude Code 安装流程已完成。%n%n请打开新的 PowerShell 或 CMD 窗口，运行 "claude" 命令开始使用。

[Files]
Source: "install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "configure-api.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "ClaudeCodeGUI.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "一键安装.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "配置API.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "start.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "Claude Code 使用说明.pdf"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式（API 配置工具）"; GroupDescription: "快捷方式:"

[Icons]
Name: "{group}\Claude Code - 配置 API"; Filename: "{app}\配置API.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 21
Name: "{group}\Claude Code - 启动助手"; Filename: "{app}\start.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14
Name: "{group}\Claude Code - 重新安装"; Filename: "{app}\一键安装.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 162
Name: "{group}\打开 PowerShell"; Filename: "powershell.exe"; WorkingDir: "{userdesktop}"
Name: "{commondesktop}\Claude Code 安装与配置"; Filename: "{app}\start.bat"; IconFilename: "{sys}\shell32.dll"; IconIndex: 14; Tasks: desktopicon

[Run]
Filename: "{app}\start.bat"; Description: "启动 Claude Code 安装与 API 配置助手"; Flags: postinstall shellexec nowait



