Import-Module "$env:TEMP\PS2EXE-master\Module\ps2exe.psm1"

$src = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1"
$out = "D:\gongsi\claude-code-cn-installer-main\Output\ClaudeCode-Setup-v1.0.0.exe"

Write-Host "Testing if source file has syntax errors..."
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $src -Raw), [ref]$errors)
if ($errors.Count -gt 0) {
    Write-Host "ERROR: Source file has syntax errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  Line $($_.Token.StartLine): $($_.Message)" -ForegroundColor Red }
    exit 1
}
Write-Host "Source file syntax OK" -ForegroundColor Green

Write-Host ""
Write-Host "Compiling with verbose output..."

Invoke-ps2exe `
    -InputFile $src `
    -OutputFile $out `
    -noConsole `
    -title "Claude Code 安装配置助手" `
    -description "Claude Code / Codex 一键安装配置工具 (中国版)" `
    -company "2api.cloud" `
    -version "1.0.0" `
    -verbose

if (Test-Path $out) {
    $size = (Get-Item $out).Length / 1KB
    Write-Host ""
    Write-Host "OK: $out ($([math]::Round($size))KB)" -ForegroundColor Green

    Write-Host ""
    Write-Host "Testing exe launch..."
    $proc = Start-Process -FilePath $out -PassThru -WindowStyle Normal
    Start-Sleep -Seconds 2

    if ($proc.HasExited) {
        Write-Host "WARNING: Process exited immediately with code $($proc.ExitCode)" -ForegroundColor Yellow
    } else {
        Write-Host "Process is running (PID: $($proc.Id))" -ForegroundColor Green
        Start-Sleep -Seconds 3
        if (-not $proc.HasExited) {
            Write-Host "Window appears to be open, closing test..." -ForegroundColor Green
            $proc.CloseMainWindow() | Out-Null
        }
    }
} else {
    Write-Host "ERROR: exe not generated" -ForegroundColor Red
}
