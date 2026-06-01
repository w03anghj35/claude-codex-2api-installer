# 简单的 UTF-8 with BOM 转换
$src = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1"

# 读取所有行
$lines = Get-Content -Path $src -Encoding UTF8

# 写回（PowerShell 的 Out-File -Encoding UTF8 会自动添加 BOM）
$lines | Out-File -FilePath $src -Encoding UTF8 -Force

Write-Host "OK: File saved as UTF-8 with BOM" -ForegroundColor Green
Write-Host "Lines: $($lines.Count)"
