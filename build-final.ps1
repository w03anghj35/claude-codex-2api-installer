Import-Module "$env:TEMP\PS2EXE-master\Module\ps2exe.psm1"

$src = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1"
$out = "D:\gongsi\claude-code-cn-installer-main\Output\ClaudeCode-Setup-v1.0.0.exe"

Write-Host "Compiling GUI to exe..."

Invoke-ps2exe `
    -InputFile $src `
    -OutputFile $out `
    -noConsole `
    -title "Claude Code 安装配置助手" `
    -description "Claude Code / Codex 一键安装配置工具 (中国版)" `
    -company "2api.cloud" `
    -version "1.0.0"

if (Test-Path $out) {
    $size = (Get-Item $out).Length / 1KB
    Write-Host "OK: $out ($([math]::Round($size))KB)" -ForegroundColor Green
} else {
    Write-Host "ERROR: exe not generated" -ForegroundColor Red
}
