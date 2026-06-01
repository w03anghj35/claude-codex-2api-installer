# ============================================================================
# Claude Code GUI 安装程序一键下载脚本
# 使用方法: irm https://你的域名/install-gui.ps1 | iex
# ============================================================================

$ErrorActionPreference = "Stop"

# 配置下载地址（需要替换为实际的 GitHub Release 或 CDN 地址）
$DOWNLOAD_URL = "https://github.com/你的用户名/你的仓库/releases/latest/download/ClaudeCode-Setup-v1.0.0.zip"
$TEMP_DIR = "$env:TEMP\claude-code-installer"
$ZIP_FILE = "$TEMP_DIR\setup.zip"
$EXE_FILE = "$TEMP_DIR\ClaudeCode-Setup-v1.0.0.exe"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Claude Code 图形安装程序 - 一键下载" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 创建临时目录
if (Test-Path $TEMP_DIR) {
    Remove-Item $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

# 下载 zip
Write-Host "正在下载安装程序..." -ForegroundColor Green
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ZIP_FILE -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "下载完成！" -ForegroundColor Green
} catch {
    Write-Host "下载失败: $_" -ForegroundColor Red
    Write-Host "请检查网络连接或手动下载: $DOWNLOAD_URL" -ForegroundColor Yellow
    exit 1
}

# 解压
Write-Host "正在解压..." -ForegroundColor Green
Expand-Archive -Path $ZIP_FILE -DestinationPath $TEMP_DIR -Force

# 启动安装程序
if (Test-Path $EXE_FILE) {
    Write-Host "启动图形安装程序..." -ForegroundColor Green
    Write-Host ""
    Start-Process -FilePath $EXE_FILE

    Write-Host "安装程序已启动！" -ForegroundColor Green
    Write-Host "关闭安装程序后，临时文件将自动清理。" -ForegroundColor Gray
} else {
    Write-Host "错误: 找不到安装程序文件" -ForegroundColor Red
    exit 1
}
