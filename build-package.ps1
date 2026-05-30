# ============================================================================
# 打包脚本 - 在 Windows 上生成 macOS/Linux 分发压缩包到 Output 目录
# ============================================================================

$VERSION = "1.0.0"
$SCRIPT_DIR = $PSScriptRoot
$OUTPUT_DIR = Join-Path $SCRIPT_DIR "Output"
$PACKAGE_NAME = "ClaudeCode-v${VERSION}-unix"
$TEMP_DIR = Join-Path $env:TEMP $PACKAGE_NAME

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "       Claude Code 打包工具 (生成 macOS/Linux 分发包)" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  版本: $VERSION"
Write-Host "  输出目录: $OUTPUT_DIR"
Write-Host ""

# 清理旧文件
if (Test-Path $TEMP_DIR) { Remove-Item -Recurse -Force $TEMP_DIR }
New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
if (-not (Test-Path $OUTPUT_DIR)) { New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null }

# 需要打包的文件
$files = @(
    "install.sh",
    "configure-api.sh",
    "start.sh",
    "README.md"
)

foreach ($f in $files) {
    $src = Join-Path $SCRIPT_DIR $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $TEMP_DIR
        Write-Host "  [+] $f" -ForegroundColor Green
    } else {
        Write-Host "  [!] 跳过 (未找到): $f" -ForegroundColor Yellow
    }
}

# 复制 PDF 说明书
$pdf = Join-Path $SCRIPT_DIR "Claude Code 使用说明.pdf"
if (Test-Path $pdf) {
    Copy-Item $pdf -Destination $TEMP_DIR
    Write-Host "  [+] Claude Code 使用说明.pdf" -ForegroundColor Green
}

Write-Host ""

# 生成 zip
$zipFile = Join-Path $OUTPUT_DIR "${PACKAGE_NAME}.zip"
if (Test-Path $zipFile) { Remove-Item -Force $zipFile }
Compress-Archive -Path "$TEMP_DIR\*" -DestinationPath $zipFile -Force
Write-Host "  [OK] 已生成: $zipFile" -ForegroundColor Green

# 清理
Remove-Item -Recurse -Force $TEMP_DIR

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  打包完成! macOS/Linux 用户下载此文件后解压即可使用:" -ForegroundColor Green
Write-Host "    $zipFile" -ForegroundColor White
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  用户使用方式:" -ForegroundColor White
Write-Host "    unzip ${PACKAGE_NAME}.zip" -ForegroundColor Gray
Write-Host "    chmod +x *.sh" -ForegroundColor Gray
Write-Host "    ./start.sh" -ForegroundColor Gray
Write-Host ""
