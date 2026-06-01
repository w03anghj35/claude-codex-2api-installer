# 安全地转换文件编码为 UTF-8 with BOM
$src = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1"
$temp = "D:\gongsi\claude-code-cn-installer-main\ClaudeCodeGUI.ps1.tmp"

# 读取内容（尝试多种编码）
try {
    $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
} catch {
    $content = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::Default)
}

# 写入临时文件（UTF-8 with BOM）
$utf8WithBom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($temp, $content, $utf8WithBom)

# 验证临时文件
if ((Test-Path $temp) -and ((Get-Item $temp).Length -gt 1000)) {
    # 替换原文件
    Move-Item -Path $temp -Destination $src -Force
    Write-Host "OK: File converted to UTF-8 with BOM" -ForegroundColor Green
    Write-Host "Lines: $((Get-Content $src).Count)"
} else {
    Write-Host "ERROR: Temp file is invalid" -ForegroundColor Red
    if (Test-Path $temp) { Remove-Item $temp }
}
