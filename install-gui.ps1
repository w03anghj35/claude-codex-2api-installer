# ============================================================================
# Claude Code GUI 安装程序一键启动脚本
# 使用方法: irm https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/install-gui.ps1 | iex
# ============================================================================

$ErrorActionPreference = "Stop"

$SCRIPT_URL = "https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/ClaudeCodeGUI.ps1"
$TEMP_FILE = "$env:TEMP\ClaudeCodeGUI.ps1"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Claude Code 图形安装程序 - 一键启动" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "正在下载 GUI 安装程序..." -ForegroundColor Green
try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $SCRIPT_URL -OutFile $TEMP_FILE -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "下载完成！正在启动..." -ForegroundColor Green
} catch {
    Write-Host "下载失败: $_" -ForegroundColor Red
    exit 1
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TEMP_FILE
