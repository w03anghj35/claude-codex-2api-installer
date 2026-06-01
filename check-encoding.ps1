$bytes = [System.IO.File]::ReadAllBytes('D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1')
Write-Host "File size: $($bytes.Length) bytes"
Write-Host "First 4 bytes: $($bytes[0]) $($bytes[1]) $($bytes[2]) $($bytes[3])"
if ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    Write-Host "Encoding: UTF-8 with BOM" -ForegroundColor Green
} else {
    Write-Host "Encoding: NO BOM" -ForegroundColor Yellow
}
