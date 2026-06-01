#!/usr/bin/env bash
# ============================================================================
# Claude Code 一键安装脚本 (macOS / Linux) - 单文件自包含版
# 面向中国用户 - 支持国产大模型 API
#
# 使用方式 (复制粘贴到终端即可):
#   curl -fsSL https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh | bash
#
# 或者先下载再运行:
#   curl -O https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh
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
echo -e "  ${MAGENTA}║  Claude Code / Codex 一键安装 (macOS/Linux 中国版)      ║${NC}"
echo -e "  ${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  请选择模式:"
echo "    [1] 完整安装 (Node.js + Git + Claude Code + 配置 API)"
echo "    [2] 仅配置 / 更换 API 令牌"
echo "    [Q] 退出"
echo ""

# 如果是 pipe 模式 (curl | bash)，需要从 /dev/tty 读取输入
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

read -rp "  请选择 [1/2/Q] (默认 1): " mode_choice
mode_choice=${mode_choice:-1}

if [ "$mode_choice" = "Q" ] || [ "$mode_choice" = "q" ]; then
    echo "  已取消。"
    exit 0
fi

api_only_mode=false
if [ "$mode_choice" = "2" ]; then
    api_only_mode=true
fi

install_claude=false
install_codex=false

if [ "$api_only_mode" = false ]; then
    echo ""
    echo "  本脚本将自动完成:"
    echo "    1. 安装 Node.js (国内镜像)"
    echo "    2. 安装 Git"
    echo "    3. 配置 npm 国内镜像源"
    echo "    4. 安装 Claude Code / Codex"
    echo "    5. 配置 API 令牌"
    echo ""
    echo "  请选择要安装的工具:"
    echo "    [1] Claude Code (推荐)"
    echo "    [2] Codex"
    echo "    [3] 两个都装"
    echo ""

    read -rp "  请选择 [1-3] (默认 1): " tool_choice
    tool_choice=${tool_choice:-1}

    case "$tool_choice" in
        1) install_claude=true ;;
        2) install_codex=true ;;
        3) install_claude=true; install_codex=true ;;
        *) install_claude=true ;;
    esac

    read -rp "  按 Enter 开始安装，输入 Q 退出: " confirm
    if [ "$confirm" = "Q" ] || [ "$confirm" = "q" ]; then
        echo "  已取消。"
        exit 0
    fi
else
    install_claude=true
fi

echo "[$(date)] 安装开始" > "$INSTALL_LOG"
SUDO=$(need_sudo)

# ---------------------------------------------------------------------------
# 步骤 1-4: 安装环境 (仅配置 API 模式跳过)
# ---------------------------------------------------------------------------
if [ "$api_only_mode" = false ]; then

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
# 步骤 4: 安装工具
# ---------------------------------------------------------------------------
step "步骤 4/5: 安装工具"

if [ "$install_claude" = true ]; then
    if command_exists claude; then
        info "Claude Code $(claude --version 2>/dev/null) 已安装"
    elif command_exists npm; then
        info "正在安装 Claude Code (使用国内镜像，请稍候)..."
        npm install -g @anthropic-ai/claude-code 2>&1 | tail -5
        export PATH="$(npm prefix -g)/bin:$PATH"
        if command_exists claude; then
            info "Claude Code 安装成功"
        else
            warn "安装完成，但需要重启终端才能使用 claude 命令"
        fi
    else
        err "npm 不可用，无法安装 Claude Code"
    fi
fi

if [ "$install_codex" = true ]; then
    # 先安装 Codex CLI
    if command_exists codex; then
        info "Codex CLI $(codex --version 2>/dev/null) 已安装"
    elif command_exists npm; then
        info "正在安装 Codex CLI (使用国内镜像，请稍候)..."
        npm install -g @openai/codex 2>&1 | tail -5
        export PATH="$(npm prefix -g)/bin:$PATH"
        if command_exists codex; then
            info "Codex CLI 安装成功"
        else
            warn "安装完成，但需要重启终端才能使用 codex 命令"
        fi
    else
        err "npm 不可用，无法安装 Codex CLI"
    fi

    # 询问是否安装桌面版
    echo ""
    read -rp "  是否安装 Codex 桌面版? [y/N]: " install_desktop
    if [ "$install_desktop" = "y" ] || [ "$install_desktop" = "Y" ]; then
        echo ""
        echo -e "  ${CYAN}正在打开 Codex 桌面版下载页面...${NC}"
        open_url "https://openai.com/codex/"
        echo ""
        read -rp "  请下载安装 Codex 桌面版，安装完成后按 Enter 继续"
    fi
fi

fi # end if api_only_mode = false

# ---------------------------------------------------------------------------
# 步骤 5: 配置 API
# ---------------------------------------------------------------------------
step "配置 API 令牌"

echo ""
echo "  需要一个 API 令牌才能运行。"
echo -e "  获取令牌: ${CYAN}${TOKEN_URL}${NC}"
echo ""

read -rp "  是否打开浏览器获取令牌? [Y/n]: " open_browser
if [ "$open_browser" != "n" ] && [ "$open_browser" != "N" ]; then
    open_url "$TOKEN_URL"
    info "已尝试打开浏览器，如未打开请手动访问上面的地址"
    echo ""
fi

read -rp "  请粘贴你的令牌 (输入 S 跳过): " api_key

if [ -z "$api_key" ] || [ "$api_key" = "S" ] || [ "$api_key" = "s" ]; then
    info "跳过 API 配置，稍后可重新运行本脚本"
else
    echo ""
    read -rp "  输入模型名 (留空使用服务默认，推荐直接回车): " selected_model

    # 配置 Claude Code
    if [ "$install_claude" = true ]; then
        mkdir -p "$SETTINGS_DIR"
        base_url_no_slash="${DEFAULT_BASE_URL%/}"

        # 清理可能冲突的 ANTHROPIC_API_KEY 环境变量
        unset ANTHROPIC_API_KEY 2>/dev/null || true

        if [ -z "$selected_model" ]; then
            cat > "$SETTINGS_PATH" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${api_key}",
    "ANTHROPIC_BASE_URL": "${base_url_no_slash}"
  }
}
EOF
        else
            cat > "$SETTINGS_PATH" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${api_key}",
    "ANTHROPIC_BASE_URL": "${base_url_no_slash}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${selected_model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${selected_model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${selected_model}",
    "ANTHROPIC_MODEL": "${selected_model}"
  }
}
EOF
        fi
        info "Claude Code 配置完成"
    fi

    # 配置 Codex
    if [ "$install_codex" = true ]; then
        codex_home="$HOME/.codex"
        mkdir -p "$codex_home"

        cat > "$codex_home/auth.json" << EOF
{
  "OPENAI_API_KEY": "${api_key}"
}
EOF

        codex_base_url="https://2api.cloud/v1"
        codex_config="model_provider = \"88code\"\n"
        if [ -n "$selected_model" ]; then
            codex_config="${codex_config}model = \"${selected_model}\"\n"
        fi
        codex_config="${codex_config}\n[model_providers.88code]\nname = \"88code\"\nbase_url = \"${codex_base_url}\"\nwire_api = \"responses\"\nrequires_openai_auth = true\n"
        echo -e "$codex_config" > "$codex_home/config.toml"
        info "Codex 配置完成"
    fi

    echo ""
    if [ -z "$selected_model" ]; then
        info "模型: 使用服务默认"
    else
        info "模型: $selected_model"
    fi

    # 测试 API 连接
    echo ""
    echo -e "  ${CYAN}正在测试 API 连接...${NC}"
    test_success=false
    max_retries=3
    retry_count=0

    while [ "$test_success" = false ] && [ $retry_count -lt $max_retries ]; do
        test_url="${DEFAULT_BASE_URL}v1/models"
        if command_exists curl; then
            response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" --max-time 10 "$test_url" 2>/dev/null)
            http_code=$(echo "$response" | tail -n1)

            if [ "$http_code" = "200" ]; then
                info "API 连接测试成功"
                test_success=true
            else
                retry_count=$((retry_count + 1))
                warn "API 连接测试失败 (尝试 $retry_count/$max_retries): HTTP $http_code"

                if [ $retry_count -lt $max_retries ]; then
                    echo ""
                    echo -e "  ${YELLOW}可能的原因:${NC}"
                    echo -e "    ${GRAY}1. 令牌错误或已过期${NC}"
                    echo -e "    ${GRAY}2. 网络连接问题${NC}"
                    echo -e "    ${GRAY}3. API 服务暂时不可用${NC}"
                    echo ""

                    read -rp "  [1] 打开配置文件手动修改  [2] 重新测试  [3] 跳过 (默认 1): " action
                    action=${action:-1}

                    if [ "$action" = "1" ]; then
                        if [ "$install_claude" = true ] && [ -f "$SETTINGS_PATH" ]; then
                            echo -e "  ${CYAN}正在打开 Claude Code 配置文件...${NC}"
                            if command_exists code; then
                                code "$SETTINGS_PATH"
                            elif command_exists nano; then
                                nano "$SETTINGS_PATH"
                            elif command_exists vi; then
                                vi "$SETTINGS_PATH"
                            else
                                echo -e "  ${YELLOW}请手动编辑: $SETTINGS_PATH${NC}"
                            fi
                        fi
                        if [ "$install_codex" = true ] && [ -f "$HOME/.codex/auth.json" ]; then
                            echo -e "  ${CYAN}正在打开 Codex 配置文件...${NC}"
                            if command_exists code; then
                                code "$HOME/.codex/auth.json"
                            elif command_exists nano; then
                                nano "$HOME/.codex/auth.json"
                            elif command_exists vi; then
                                vi "$HOME/.codex/auth.json"
                            else
                                echo -e "  ${YELLOW}请手动编辑: $HOME/.codex/auth.json${NC}"
                            fi
                        fi
                        echo ""
                        read -rp "  修改完成后按 Enter 重新测试"

                        # 重新读取配置
                        if [ "$install_claude" = true ] && [ -f "$SETTINGS_PATH" ]; then
                            new_key=$(grep -oP '"ANTHROPIC_AUTH_TOKEN":\s*"\K[^"]+' "$SETTINGS_PATH" 2>/dev/null)
                            if [ -n "$new_key" ]; then
                                api_key="$new_key"
                            fi
                        fi
                    elif [ "$action" = "3" ]; then
                        warn "跳过 API 测试，请稍后手动验证"
                        break
                    fi
                else
                    warn "已达到最大重试次数，请稍后手动验证配置"
                fi
            fi
        else
            warn "未找到 curl，跳过 API 连接测试"
            break
        fi
    done
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
if [ "$install_claude" = true ]; then
    echo -e "    ${CYAN}claude${NC}"
fi
if [ "$install_codex" = true ]; then
    echo -e "    ${CYAN}codex${NC}"
fi
echo ""

# 状态检测
echo "  安装状态:"
command_exists node && info "Node.js $(node --version 2>/dev/null)" || err "Node.js 未检测到"
command_exists git  && info "$(git --version 2>/dev/null)"          || err "Git 未检测到"
if [ "$install_claude" = true ]; then
    command_exists claude && info "Claude Code 已就绪" || warn "Claude Code 需重启终端"
fi
if [ "$install_codex" = true ]; then
    command_exists codex && info "Codex 已就绪" || warn "Codex 需重启终端"
fi
if [ -f "$SETTINGS_PATH" ] && grep -q "ANTHROPIC_AUTH_TOKEN" "$SETTINGS_PATH" 2>/dev/null; then
    info "API 令牌已配置"
elif [ -f "$HOME/.codex/auth.json" ]; then
    info "API 令牌已配置"
else
    warn "API 令牌未配置"
fi
echo ""
