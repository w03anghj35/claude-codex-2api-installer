#!/usr/bin/env bash
# ============================================================================
# Claude Code 一键安装脚本 (macOS / Linux) - 单文件自包含版
# 面向中国用户 - 支持国产大模型 API
#
# 使用方式 (复制粘贴到终端即可):
#   curl -fsSL https://raw.githubusercontent.com/你的用户名/claude-code-cn-installer/main/setup.sh | bash
#
# 或者先下载再运行:
#   curl -O https://raw.githubusercontent.com/你的用户名/claude-code-cn-installer/main/setup.sh
#   bash setup.sh
# ============================================================================

set -e

# ---------------------------------------------------------------------------
# 全局配置
# ---------------------------------------------------------------------------
NODEJS_VERSION="22.13.1"
NPM_MIRROR="https://registry.npmmirror.com"
INSTALL_LOG="/tmp/claude-code-install.log"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_PATH="$SETTINGS_DIR/settings.json"
DEFAULT_BASE_URL="https://2api.cloud/"
TOKEN_URL="https://2api.cloud/console/token"

# ---------------------------------------------------------------------------
# 颜色
# ---------------------------------------------------------------------------
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
info()  { echo -e "  ${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[!]${NC} $1"; }
err()   { echo -e "  ${RED}[✗]${NC} $1"; }
step()  { echo ""; echo -e "  ${CYAN}▶ $1${NC}"; echo ""; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)             echo "x64" ;;
    esac
}

open_url() {
    case "$(detect_os)" in
        macos) open "$1" 2>/dev/null || true ;;
        linux) xdg-open "$1" 2>/dev/null || true ;;
    esac
}

need_sudo() {
    if [ "$(detect_os)" = "linux" ] && [ "$EUID" -ne 0 ]; then
        echo "sudo"
    else
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# 欢迎
# ---------------------------------------------------------------------------
clear 2>/dev/null || true
echo ""
echo -e "  ${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${MAGENTA}║       Claude Code 一键安装 (macOS/Linux 中国版)         ║${NC}"
echo -e "  ${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  本脚本将自动完成:"
echo "    1. 安装 Node.js (国内镜像)"
echo "    2. 安装 Git"
echo "    3. 配置 npm 国内镜像源"
echo "    4. 安装 Claude Code"
echo "    5. 配置 API 令牌"
echo ""

# 如果是 pipe 模式 (curl | bash)，需要从 /dev/tty 读取输入
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

read -rp "  按 Enter 开始安装，输入 Q 退出: " confirm
if [ "$confirm" = "Q" ] || [ "$confirm" = "q" ]; then
    echo "  已取消。"
    exit 0
fi

echo "[$(date)] 安装开始" > "$INSTALL_LOG"
SUDO=$(need_sudo)

# ---------------------------------------------------------------------------
# 步骤 1: Node.js
# ---------------------------------------------------------------------------
step "步骤 1/5: 检查 Node.js"

install_node=true
if command_exists node; then
    node_ver=$(node --version 2>/dev/null)
    major=$(echo "$node_ver" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$major" -ge 18 ] && command_exists npm; then
        info "Node.js $node_ver 已安装，版本满足要求"
        install_node=false
    else
        warn "Node.js 版本过低或 npm 缺失，将安装新版本"
    fi
fi

if [ "$install_node" = true ]; then
    os=$(detect_os)
    arch=$(detect_arch)

    if [ "$os" = "macos" ]; then
        if command_exists brew; then
            info "使用 Homebrew 安装 Node.js 22..."
            brew install node@22 2>&1 | tail -3
            brew link --overwrite node@22 2>/dev/null || true
        else
            info "从 npmmirror 下载 Node.js..."
            curl -fSL --progress-bar \
                "https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}.pkg" \
                -o /tmp/node.pkg
            sudo installer -pkg /tmp/node.pkg -target /
            rm -f /tmp/node.pkg
        fi
    elif [ "$os" = "linux" ]; then
        info "从 npmmirror 下载 Node.js 二进制包..."
        curl -fSL --progress-bar \
            "https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-${arch}.tar.xz" \
            -o /tmp/node.tar.xz
        $SUDO tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
        rm -f /tmp/node.tar.xz
    fi

    if command_exists node; then
        info "Node.js $(node --version) 安装成功"
    else
        err "Node.js 安装失败，请手动安装: https://npmmirror.com/mirrors/node/"
    fi
fi

# ---------------------------------------------------------------------------
# 步骤 2: Git
# ---------------------------------------------------------------------------
step "步骤 2/5: 检查 Git"

if command_exists git; then
    info "$(git --version) 已安装"
else
    os=$(detect_os)
    if [ "$os" = "macos" ]; then
        info "安装 Xcode Command Line Tools (含 Git)..."
        xcode-select --install 2>/dev/null || true
        warn "如果弹出安装窗口，请点击安装并等待完成后重新运行本脚本"
    elif [ "$os" = "linux" ]; then
        if command_exists apt-get; then
            $SUDO apt-get update -qq && $SUDO apt-get install -y -qq git
        elif command_exists dnf; then
            $SUDO dnf install -y git
        elif command_exists pacman; then
            $SUDO pacman -S --noconfirm git
        elif command_exists apk; then
            $SUDO apk add git
        fi
    fi

    if command_exists git; then
        info "$(git --version) 安装成功"
    else
        err "Git 安装失败，请手动安装"
    fi
fi

# ---------------------------------------------------------------------------
# 步骤 3: npm 镜像
# ---------------------------------------------------------------------------
step "步骤 3/5: 配置 npm 国内镜像源"

if command_exists npm; then
    npm config set registry "$NPM_MIRROR" 2>/dev/null
    info "npm 镜像源已设置为: $NPM_MIRROR"
else
    err "npm 未找到，请确保 Node.js 安装成功"
fi

# ---------------------------------------------------------------------------
# 步骤 4: Claude Code
# ---------------------------------------------------------------------------
step "步骤 4/5: 安装 Claude Code"

if command_exists claude; then
    info "Claude Code $(claude --version 2>/dev/null) 已安装"
elif command_exists npm; then
    info "正在安装 Claude Code (使用国内镜像，请稍候)..."
    npm install -g @anthropic-ai/claude-code 2>&1 | tail -5

    # 刷新 PATH
    export PATH="$(npm prefix -g)/bin:$PATH"

    if command_exists claude; then
        info "Claude Code 安装成功"
    else
        warn "安装完成，但需要重启终端才能使用 claude 命令"
    fi
else
    err "npm 不可用，无法安装 Claude Code"
fi

# ---------------------------------------------------------------------------
# 步骤 5: 配置 API
# ---------------------------------------------------------------------------
step "步骤 5/5: 配置 API 令牌"

echo ""
echo "  Claude Code 需要一个 API 令牌才能运行。"
echo -e "  获取令牌: ${CYAN}${TOKEN_URL}${NC}"
echo ""
echo "  可用模型:"
echo "    [1] glm-5         - 旗舰模型，最强 (推荐)"
echo "    [2] glm-4.7       - 编程增强，日常使用"
echo "    [3] glm-4.5       - Agent 基座"
echo "    [4] glm-4.7-flash - 轻量快速"
echo "    [5] glm-4-flash   - 免费模型"
echo "    [6] 跳过，稍后手动配置"
echo ""

glm_models=("glm-5" "glm-4.7" "glm-4.5" "glm-4.7-flash" "glm-4-flash")

read -rp "  请选择模型 [1-6] (默认 1): " model_choice
model_choice=${model_choice:-1}

if [ "$model_choice" -ge 1 ] 2>/dev/null && [ "$model_choice" -le 5 ] 2>/dev/null; then
    echo ""
    read -rp "  是否打开浏览器获取令牌? [Y/n]: " open_browser
    if [ "$open_browser" != "n" ] && [ "$open_browser" != "N" ]; then
        open_url "$TOKEN_URL"
        info "已尝试打开浏览器，如未打开请手动访问上面的地址"
        echo ""
    fi

    read -rp "  请粘贴你的令牌: " api_key

    if [ -z "$api_key" ]; then
        warn "未输入令牌，跳过配置"
        warn "稍后可运行: bash setup.sh 重新配置"
    else
        idx=$((model_choice - 1))
        opus_model="${glm_models[$idx]}"
        if [ "$idx" -le 1 ]; then
            sonnet_model="glm-4.7"
        else
            sonnet_model="${glm_models[$idx]}"
        fi
        haiku_model="glm-4.5-air"

        mkdir -p "$SETTINGS_DIR"
        cat > "$SETTINGS_PATH" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "${DEFAULT_BASE_URL}",
    "ANTHROPIC_API_KEY": "${api_key}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${opus_model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${sonnet_model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${haiku_model}"
  }
}
EOF
        echo ""
        info "配置完成!"
        info "  主力模型: $opus_model"
        info "  日常模型: $sonnet_model"
        info "  轻量模型: $haiku_model"
    fi
else
    info "跳过 API 配置，稍后可重新运行本脚本"
fi

# ---------------------------------------------------------------------------
# 完成
# ---------------------------------------------------------------------------
echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║                    安装完成!                            ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  现在打开一个新的终端窗口，运行:"
echo ""
echo -e "    ${CYAN}claude${NC}"
echo ""
echo "  测试连接:"
echo ""
echo -e "    ${CYAN}claude -p \"你好\" --output-format text${NC}"
echo ""

# 状态检测
echo "  安装状态:"
command_exists node   && info "Node.js $(node --version 2>/dev/null)" || err "Node.js 未检测到"
command_exists git    && info "$(git --version 2>/dev/null)"          || err "Git 未检测到"
command_exists claude && info "Claude Code 已就绪"                    || warn "Claude Code 需重启终端"
[ -f "$SETTINGS_PATH" ] && grep -q "ANTHROPIC_API_KEY" "$SETTINGS_PATH" 2>/dev/null \
    && info "API 令牌已配置" || warn "API 令牌未配置"
echo ""
