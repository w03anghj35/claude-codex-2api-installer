#!/bin/bash
# ============================================================================
# PyInstaller 打包脚本 - macOS
# Mac 用户运行此脚本打包 .app
# ============================================================================

echo "正在打包 Python GUI 为 macOS .app..."

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 Python3，正在通过 brew 安装..."
    if ! command -v brew &> /dev/null; then
        echo "正在安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install python3
fi

# 检查 pyinstaller
if ! python3 -c "import PyInstaller" 2>/dev/null; then
    echo "正在安装 pyinstaller..."
    pip3 install pyinstaller
fi

# 打包
python3 -m PyInstaller \
    --name="ClaudeCode-Setup" \
    --onefile \
    --windowed \
    --clean \
    ClaudeCodeGUI.py

if [ $? -eq 0 ]; then
    echo "打包成功！"
    echo "输出文件: dist/ClaudeCode-Setup"

    mkdir -p Output
    cp -f "dist/ClaudeCode-Setup" "Output/ClaudeCode-Setup-mac"
    echo "已复制到: Output/ClaudeCode-Setup-mac"
    echo ""
    echo "请将 Output/ClaudeCode-Setup-mac 发送给项目维护者上传到 Release。"
else
    echo "打包失败！"
    exit 1
fi
