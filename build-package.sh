#!/usr/bin/env bash
# ============================================================================
# 打包脚本 - 生成 macOS/Linux 分发压缩包到 Output 目录
# 类似 Windows 的 Inno Setup 打包流程
# ============================================================================

set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/Output"
PACKAGE_NAME="ClaudeCode-v${VERSION}-unix"
TEMP_DIR="/tmp/$PACKAGE_NAME"

echo ""
echo "  ================================================================"
echo "       Claude Code 打包工具 (macOS/Linux)"
echo "  ================================================================"
echo ""
echo "  版本: $VERSION"
echo "  输出目录: $OUTPUT_DIR"
echo ""

# 清理旧文件
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

# 复制需要打包的文件
FILES=(
    "install.sh"
    "configure-api.sh"
    "start.sh"
    "README.md"
)

for f in "${FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$f" ]; then
        cp "$SCRIPT_DIR/$f" "$TEMP_DIR/"
        echo "  [+] $f"
    else
        echo "  [!] 跳过 (未找到): $f"
    fi
done

# 复制 PDF 说明书（如果存在）
if [ -f "$SCRIPT_DIR/Claude Code 使用说明.pdf" ]; then
    cp "$SCRIPT_DIR/Claude Code 使用说明.pdf" "$TEMP_DIR/"
    echo "  [+] Claude Code 使用说明.pdf"
fi

# 确保脚本有执行权限
chmod +x "$TEMP_DIR"/*.sh 2>/dev/null || true

echo ""

# 生成 tar.gz
TARGZ_FILE="$OUTPUT_DIR/${PACKAGE_NAME}.tar.gz"
tar -czf "$TARGZ_FILE" -C /tmp "$PACKAGE_NAME"
echo "  [OK] 已生成: $TARGZ_FILE"

# 生成 zip
ZIP_FILE="$OUTPUT_DIR/${PACKAGE_NAME}.zip"
if command -v zip >/dev/null 2>&1; then
    (cd /tmp && zip -r "$ZIP_FILE" "$PACKAGE_NAME")
    echo "  [OK] 已生成: $ZIP_FILE"
else
    echo "  [跳过] zip 命令未安装，未生成 .zip 文件"
fi

# 清理临时目录
rm -rf "$TEMP_DIR"

echo ""
echo "  ================================================================"
echo "  打包完成! 分发文件位于: $OUTPUT_DIR"
echo "  ================================================================"
echo ""
ls -lh "$OUTPUT_DIR"/*unix* 2>/dev/null || true
echo ""
