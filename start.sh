#!/usr/bin/env bash
# ============================================================================
# Claude Code 安装配置助手 - 入口脚本 (macOS / Linux)
# 等同于 Windows 的 start.bat
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  ================================================================"
echo "       Claude Code 安装配置助手 (macOS/Linux)"
echo "  ================================================================"
echo ""
echo "  请选择操作:"
echo "    [1] 一键安装 Claude Code (安装 Node.js + Git + Claude Code + 配置 API)"
echo "    [2] 仅配置/修改 API"
echo "    [Q] 退出"
echo ""

read -rp "  请输入选项: " choice

case "$choice" in
    1)
        echo ""
        echo "  启动安装脚本..."
        bash "$SCRIPT_DIR/install.sh"
        ;;
    2)
        echo ""
        echo "  启动 API 配置工具..."
        bash "$SCRIPT_DIR/configure-api.sh"
        ;;
    Q|q)
        echo "  已退出。"
        exit 0
        ;;
    *)
        echo "  无效选项，已退出。"
        exit 1
        ;;
esac
