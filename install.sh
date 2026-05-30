#!/usr/bin/env bash
# ============================================================================
# Claude Code 一键安装脚本 (macOS / Linux)
# 面向中国用户 - 支持国产大模型 API
# ============================================================================

set -e

# ---------------------------------------------------------------------------
# 全局配置
# ---------------------------------------------------------------------------
NODEJS_VERSION="22.13.1"
NPM_MIRROR="https://registry.npmmirror.com"
INSTALL_LOG="/tmp/claude-code-install.log"
SKIP_API_CONFIG="${SKIP_API_CONFIG:-false}"
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------
write_step() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo "[$(date)] $1" >> "$INSTALL_LOG"
}

write_info() {
    echo -e "  ${GREEN}[信息]${NC} $1"
    echo "[$(date)] INFO: $1" >> "$INSTALL_LOG"
}

write_warn() {
    echo -e "  ${YELLOW}[警告]${NC} $1"
    echo "[$(date)] WARN: $1" >> "$INSTALL_LOG"
}

write_err() {
    echo -e "  ${RED}[错误]${NC} $1"
    echo "[$(date)] ERROR: $1" >> "$INSTALL_LOG"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "x64" ;;
    esac
}

open_url() {
    local url="$1"
    case "$(detect_os)" in
        macos) open "$url" 2>/dev/null ;;
        linux)
            if command_exists xdg-open; then
                xdg-open "$url" 2>/dev/null
            elif command_exists gnome-open; then
                gnome-open "$url" 2>/dev/null
            else
                write_info "请手动打开: $url"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# 检查 root 权限 (Linux 需要, macOS 可选)
# ---------------------------------------------------------------------------
check_permissions() {
    local os
    os=$(detect_os)
    if [ "$os" = "linux" ] && [ "$EUID" -ne 0 ]; then
        write_warn "建议以 root 权限运行 (sudo ./install.sh)"
        write_warn "部分安装步骤可能需要管理员权限"
        echo ""
        read -rp "  继续安装? (Y/n) " confirm
        if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
            echo "  安装已取消。"
            exit 0
        fi
    fi
}

# ---------------------------------------------------------------------------
# 欢迎界面
# ---------------------------------------------------------------------------
clear
echo ""
echo -e "  ${MAGENTA}================================================================${NC}"
echo -e "  ${MAGENTA}     Claude Code 一键安装工具 (macOS/Linux 中国版)${NC}"
echo -e "  ${MAGENTA}================================================================${NC}"
echo ""
echo "  本工具将自动完成以下操作:"
echo "    1. 检查并安装 Node.js (使用国内镜像)"
echo "    2. 检查并安装 Git"
echo "    3. 配置 npm 国内镜像源"
echo "    4. 安装 Claude Code (npm)"
echo "    5. 配置智谱 GLM API"
echo ""

if [ "$NON_INTERACTIVE" != "true" ]; then
    read -rp "  按 Enter 继续安装，输入 Q 退出: " confirm
    if [ "$confirm" = "Q" ] || [ "$confirm" = "q" ]; then
        echo -e "  ${YELLOW}安装已取消。${NC}"
        exit 0
    fi
fi

check_permissions

echo "[$(date)] Claude Code 安装开始" > "$INSTALL_LOG"

# ---------------------------------------------------------------------------
# 步骤 1: 安装 Node.js
# ---------------------------------------------------------------------------
write_step "步骤 1/5: 检查 Node.js"

skip_node=false
if command_exists node; then
    node_ver=$(node --version 2>/dev/null)
    write_info "Node.js 已安装: $node_ver"

    major_version=$(echo "$node_ver" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$major_version" -lt 18 ]; then
        write_warn "Node.js 版本过低 (需要 >= 18)，将升级..."
    elif ! command_exists npm; then
        write_warn "Node.js 已安装但 npm 未检测到，将重新安装..."
    else
        write_info "Node.js 版本满足要求，跳过安装"
        skip_node=true
    fi
fi

if [ "$skip_node" = false ]; then
    os=$(detect_os)
    arch=$(detect_arch)

    if [ "$os" = "macos" ]; then
        if command_exists brew; then
            write_info "使用 Homebrew 安装 Node.js..."
            brew install node@22 2>&1 | tail -5
            brew link --overwrite node@22 2>/dev/null || true
        else
            write_info "未检测到 Homebrew，使用 npmmirror 下载安装..."
            node_pkg="/tmp/nodejs-installer.pkg"
            node_url="https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}.pkg"
            write_info "下载地址: $node_url"
            curl -fSL --progress-bar -o "$node_pkg" "$node_url"
            if [ -f "$node_pkg" ]; then
                sudo installer -pkg "$node_pkg" -target / 2>/dev/null
                write_info "Node.js 安装成功"
                rm -f "$node_pkg"
            else
                write_err "Node.js 下载失败"
                write_err "请手动安装: https://npmmirror.com/mirrors/node/"
            fi
        fi
    elif [ "$os" = "linux" ]; then
        if command_exists apt-get; then
            write_info "使用 NodeSource 安装 Node.js 22.x..."
            curl -fsSL https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-${arch}.tar.xz -o /tmp/node.tar.xz
            if [ -f /tmp/node.tar.xz ]; then
                sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
                write_info "Node.js 安装成功"
                rm -f /tmp/node.tar.xz
            else
                write_err "Node.js 下载失败"
                write_err "请手动安装: https://npmmirror.com/mirrors/node/"
            fi
        elif command_exists dnf; then
            write_info "使用二进制包安装 Node.js..."
            curl -fsSL https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-${arch}.tar.xz -o /tmp/node.tar.xz
            if [ -f /tmp/node.tar.xz ]; then
                sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
                write_info "Node.js 安装成功"
                rm -f /tmp/node.tar.xz
            else
                write_err "Node.js 下载失败"
            fi
        elif command_exists pacman; then
            write_info "使用 pacman 安装 Node.js..."
            sudo pacman -S --noconfirm nodejs npm
        else
            write_err "未检测到支持的包管理器"
            write_err "请手动安装 Node.js >= 18: https://npmmirror.com/mirrors/node/"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 步骤 2: 安装 Git
# ---------------------------------------------------------------------------
write_step "步骤 2/5: 检查 Git"

if command_exists git; then
    git_ver=$(git --version 2>/dev/null)
    write_info "Git 已安装: $git_ver"
    write_info "跳过 Git 安装"
else
    os=$(detect_os)
    if [ "$os" = "macos" ]; then
        write_info "macOS 通常自带 Git (Xcode Command Line Tools)"
        write_info "正在安装 Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        write_warn "如果弹出安装窗口，请点击安装并等待完成"
    elif [ "$os" = "linux" ]; then
        if command_exists apt-get; then
            write_info "使用 apt 安装 Git..."
            sudo apt-get update -qq && sudo apt-get install -y -qq git
        elif command_exists dnf; then
            write_info "使用 dnf 安装 Git..."
            sudo dnf install -y git
        elif command_exists pacman; then
            write_info "使用 pacman 安装 Git..."
            sudo pacman -S --noconfirm git
        elif command_exists apk; then
            write_info "使用 apk 安装 Git..."
            sudo apk add git
        else
            write_err "请手动安装 Git"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 步骤 3: 配置 npm 镜像源
# ---------------------------------------------------------------------------
write_step "步骤 3/5: 配置 npm 国内镜像源"

if command_exists npm; then
    write_info "设置 npm 镜像源为: $NPM_MIRROR"
    npm config set registry "$NPM_MIRROR"
    write_info "npm 镜像源配置完成"

    current_registry=$(npm config get registry)
    write_info "当前 npm 镜像源: $current_registry"
else
    write_err "npm 未找到，请确保 Node.js 安装成功后重试"
fi

# ---------------------------------------------------------------------------
# 步骤 4: 安装 Claude Code
# ---------------------------------------------------------------------------
write_step "步骤 4/5: 安装 Claude Code"

if command_exists claude; then
    claude_ver=$(claude --version 2>/dev/null)
    write_info "Claude Code 已安装: $claude_ver"
    write_info "跳过 Claude Code 安装"
elif command_exists npm; then
    write_info "正在通过 npm 安装 Claude Code ..."
    write_info "（使用国内镜像源，请耐心等待）"

    if npm install -g @anthropic-ai/claude-code 2>&1 | tail -20; then
        if command_exists claude; then
            claude_ver=$(claude --version 2>/dev/null)
            write_info "Claude Code 安装成功: $claude_ver"
        else
            write_warn "claude 命令未找到，可能需要重启终端"
            write_info "安装完成后请打开新的终端窗口运行 'claude' 命令"
        fi
    else
        write_err "Claude Code 安装失败"
        write_err "请手动运行: npm install -g @anthropic-ai/claude-code"
    fi
else
    write_err "npm 不可用，无法安装 Claude Code"
fi

# ---------------------------------------------------------------------------
# 步骤 5: 配置智谱 GLM API
# ---------------------------------------------------------------------------
if [ "$SKIP_API_CONFIG" = "true" ]; then
    write_step "步骤 5/5: 跳过 API 配置"
    write_info "已跳过 API 配置，可稍后运行 ./configure-api.sh 进行配置。"
else
    write_step "步骤 5/5: 配置智谱 GLM API"

    echo ""
    echo -e "  ${YELLOW}================================================================${NC}"
    echo -e "  ${YELLOW} 配置 API，让 Claude Code 通过 2api 运行${NC}"
    echo -e "  ${YELLOW}================================================================${NC}"
    echo ""
    echo -e "  ${CYAN}获取令牌: https://2api.cloud/console/token${NC}"
    echo ""
    echo "  可用模型 (留空使用服务默认模型):"
    echo "    [1] 不指定模型，使用服务默认  <- 推荐"
    echo "    [2] glm-5        - 旗舰模型 745B MoE，最强"
    echo "    [3] glm-4.7      - 编程增强 SWE-bench 73.8"
    echo "    [4] glm-4.5      - Agent 基座，工具调用优化"
    echo "    [5] glm-4.7-flash - 30B MoE 轻量快速"
    echo "    [6] glm-4-flash  - 免费模型，轻量任务"
    echo "    [7] 暂时跳过，稍后手动配置"
    echo ""

    glm_models=("" "glm-5" "glm-4.7" "glm-4.5" "glm-4.7-flash" "glm-4-flash")

    read -rp "  请输入选项编号 (1-7, 默认 1): " provider_choice
    provider_choice=${provider_choice:-1}

    if [ "$provider_choice" -ge 1 ] 2>/dev/null && [ "$provider_choice" -le 6 ] 2>/dev/null; then
        echo ""
        read -rp "  是否打开浏览器获取令牌? (Y/n): " open_browser
        if [ "$open_browser" != "n" ] && [ "$open_browser" != "N" ]; then
            open_url "https://2api.cloud/console/token"
            write_info "已打开浏览器，请获取您的令牌"
            echo ""
        fi

        read -rp "  请输入您的令牌: " api_key

        if [ -z "$api_key" ]; then
            write_warn "未输入令牌，跳过配置"
            write_warn "您可以稍后运行 ./configure-api.sh 进行配置"
        else
            model_index=$((provider_choice - 1))
            selected_model="${glm_models[$model_index]}"

            glm_base_url="https://2api.cloud/"
            claude_config_dir="$HOME/.claude"
            mkdir -p "$claude_config_dir"

            if [ -z "$selected_model" ]; then
                cat > "$claude_config_dir/settings.json" << SETTINGS_EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$glm_base_url",
    "ANTHROPIC_API_KEY": "$api_key"
  }
}
SETTINGS_EOF
                write_info "配置完成:"
                echo -e "    ${GRAY}ANTHROPIC_BASE_URL = $glm_base_url${NC}"
                echo -e "    ${GRAY}ANTHROPIC_API_KEY  = ${api_key:0:8}****${NC}"
                echo -e "    ${GRAY}模型: 使用服务默认${NC}"
            else
                cat > "$claude_config_dir/settings.json" << SETTINGS_EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$glm_base_url",
    "ANTHROPIC_API_KEY": "$api_key",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$selected_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$selected_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$selected_model"
  }
}
SETTINGS_EOF
                write_info "配置完成:"
                echo -e "    ${GRAY}ANTHROPIC_BASE_URL = $glm_base_url${NC}"
                echo -e "    ${GRAY}ANTHROPIC_API_KEY  = ${api_key:0:8}****${NC}"
                echo -e "    ${GRAY}模型: $selected_model${NC}"
            fi
            write_info "Claude Code 配置文件已写入: $claude_config_dir/settings.json"
        fi
    else
        write_info "跳过 API 配置"
        write_info "您可以稍后运行 ./configure-api.sh 进行配置"
    fi
fi

# ---------------------------------------------------------------------------
# 安装完成
# ---------------------------------------------------------------------------
echo ""
echo -e "  ${GREEN}================================================================${NC}"
echo -e "  ${GREEN}     安装完成!${NC}"
echo -e "  ${GREEN}================================================================${NC}"
echo ""
echo "  使用方法:"
echo "    1. 打开一个新的终端窗口"
echo "    2. 切换到您的项目目录"
echo "    3. 运行命令: claude"
echo ""
echo "  常用命令:"
echo -e "    ${GRAY}claude              - 启动 Claude Code 交互模式${NC}"
echo -e "    ${GRAY}claude --help       - 查看帮助信息${NC}"
echo -e "    ${GRAY}claude --version    - 查看版本信息${NC}"
echo ""
echo "  如需重新配置 API:"
echo -e "    ${GRAY}运行 ./configure-api.sh${NC}"
echo ""
echo -e "  安装日志: ${GRAY}$INSTALL_LOG${NC}"
echo ""

# 检测安装结果
echo "  安装状态检测:"

if command_exists node; then
    echo -e "    ${GREEN}[OK] Node.js $(node --version 2>/dev/null)${NC}"
else
    echo -e "    ${RED}[!!] Node.js 未检测到 (请重启终端后再试)${NC}"
fi

if command_exists git; then
    echo -e "    ${GREEN}[OK] $(git --version 2>/dev/null)${NC}"
else
    echo -e "    ${RED}[!!] Git 未检测到 (请重启终端后再试)${NC}"
fi

if command_exists claude; then
    echo -e "    ${GREEN}[OK] Claude Code 已安装${NC}"
else
    echo -e "    ${YELLOW}[!!] Claude Code 未检测到 (请重启终端后运行 'claude')${NC}"
fi

settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
    if grep -q "ANTHROPIC_API_KEY" "$settings_file" 2>/dev/null; then
        echo -e "    ${GREEN}[OK] 令牌已配置${NC}"
    else
        echo -e "    ${YELLOW}[!!] 令牌未配置 (请运行 ./configure-api.sh)${NC}"
    fi
else
    echo -e "    ${YELLOW}[!!] 令牌未配置 (请运行 ./configure-api.sh)${NC}"
fi

echo ""
if [ "$NON_INTERACTIVE" != "true" ]; then
    read -rp "  按 Enter 键退出安装程序"
fi
