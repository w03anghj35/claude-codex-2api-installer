Import-Module "$env:TEMP\PS2EXE-master\Module\ps2exe.psm1"

$src = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1"
$out = "D:\gongsi\claude-code-cn-installer-main\Output\ClaudeCode-Setup-DEBUG.exe"

Write-Host "Compiling with console for debugging..."

Invoke-ps2exe `
    -InputFile $src `
    -OutputFile $out `
    -title "Claude Code 安装配置助手 (DEBUG)" `
    -description "Claude Code / Codex 一键安装配置工具 (中国版)" `
    -company "2api.cloud" `
    -version "1.0.0"

if (Test-Path $out) {
    Write-Host "OK: $out" -ForegroundColor Green
    Write-Host ""
    Write-Host "Please run the DEBUG exe manually and check console output for errors."
    Write-Host "Path: $out"
} else {
    Write-Host "ERROR: exe not generated" -ForegroundColor Red
}
