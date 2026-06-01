# ============================================================================
# PyInstaller 打包脚本 - Windows
# ============================================================================

Write-Host "正在打包 Python GUI 为 Windows exe..." -ForegroundColor Cyan

# 检查 Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "错误: 未找到 Python，请先安装 Python 3.8+" -ForegroundColor Red
    exit 1
}

# 检查 pyinstaller
$hasInstaller = python -c "import PyInstaller" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "正在安装 pyinstaller..." -ForegroundColor Yellow
    python -m pip install pyinstaller
}

# 打包
python -m PyInstaller `
    --name="ClaudeCode-Setup" `
    --onefile `
    --windowed `
    --icon=NONE `
    --clean `
    ClaudeCodeGUI.py

if ($LASTEXITCODE -eq 0) {
    Write-Host "打包成功！" -ForegroundColor Green
    Write-Host "输出文件: dist\ClaudeCode-Setup.exe" -ForegroundColor Green

    # 移动到 Output 目录
    if (-not (Test-Path Output)) {
        New-Item -ItemType Directory -Path Output | Out-Null
    }
    Copy-Item dist\ClaudeCode-Setup.exe Output\ClaudeCode-Setup-Python.exe -Force
    Write-Host "已复制到: Output\ClaudeCode-Setup-Python.exe" -ForegroundColor Green
} else {
    Write-Host "打包失败！" -ForegroundColor Red
}
