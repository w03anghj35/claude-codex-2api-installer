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
# 配置冲突检测
# ---------------------------------------------------------------------------
check_config_conflicts() {
    local has_conflict=false

    # 检查 Claude Code 配置目录
    if [ -d "$SETTINGS_DIR" ]; then
        local json_count=$(find "$SETTINGS_DIR" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
        if [ "$json_count" -gt 1 ]; then
            warn "检测到 $SETTINGS_DIR 目录有多个 .json 配置文件，可能导致冲突"
            find "$SETTINGS_DIR" -maxdepth 1 -name "*.json" -exec echo "    - {}" \;
            has_conflict=true
        fi
    fi

    # 检查 Codex 配置目录
    if [ -d "$HOME/.codex" ]; then
        local json_count=$(find "$HOME/.codex" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
        local toml_count=$(find "$HOME/.codex" -maxdepth 1 -name "*.toml" 2>/dev/null | wc -l)
        if [ "$json_count" -gt 1 ] || [ "$toml_count" -gt 1 ]; then
            warn "检测到 $HOME/.codex 目录有多个配置文件，可能导致冲突"
            find "$HOME/.codex" -maxdepth 1 \( -name "*.json" -o -name "*.toml" \) -exec echo "    - {}" \;
            has_conflict=true
        fi
    fi

    if [ "$has_conflict" = true ]; then
        echo ""
        echo -e "  ${YELLOW}建议：删除多余的配置文件或重命名为 .bak 备份${NC}"
        echo ""
        read -rp "  按 Enter 继续..."
    fi
}

# ---------------------------------------------------------------------------
# 获取模型列表
# ---------------------------------------------------------------------------
fetch_models() {
    local api_key="$1"
    local base_url="${DEFAULT_BASE_URL%/}/v1/models"

    if command_exists curl; then
        echo -e "  ${CYAN}正在获取可用模型列表...${NC}"
        local response=$(curl -s -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" --max-time 10 "$base_url" 2>/dev/null)

        if echo "$response" | grep -q '"id"'; then
            echo ""
            echo "  可用模型："
            echo "$response" | grep -oP '"id":\s*"\K[^"]+' | nl -w2 -s'. '
            echo ""
            return 0
        fi
    fi
    return 1
}

# ---------------------------------------------------------------------------
# 步骤 5: 配置 API
# ---------------------------------------------------------------------------
step "配置 API 令牌"

# 先检测配置冲突
check_config_conflicts

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

    # 尝试获取模型列表
    if fetch_models "$api_key"; then
        read -rp "  输入模型编号或名称 (留空使用服务默认，推荐直接回车): " model_input

        # 如果输入的是数字，从列表中选择
        if [[ "$model_input" =~ ^[0-9]+$ ]]; then
            response=$(curl -s -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" --max-time 10 "${DEFAULT_BASE_URL%/}/v1/models" 2>/dev/null)
            selected_model=$(echo "$response" | grep -oP '"id":\s*"\K[^"]+' | sed -n "${model_input}p")
            if [ -z "$selected_model" ]; then
                warn "无效的模型编号，使用服务默认"
                selected_model=""
            else
                info "已选择模型: $selected_model"
            fi
        else
            selected_model="$model_input"
        fi
    else
        read -rp "  输入模型名 (留空使用服务默认，推荐直接回车): " selected_model
    fi

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
# 测试 Codex API
# ---------------------------------------------------------------------------
test_codex_api() {
    local codex_auth="$HOME/.codex/auth.json"
    local codex_config="$HOME/.codex/config.toml"

    if [ ! -f "$codex_auth" ]; then
        err "未找到 Codex 配置文件: $codex_auth"
        return 1
    fi

    # 读取 API key
    local api_key=$(grep -oP '"OPENAI_API_KEY":\s*"\K[^"]+' "$codex_auth" 2>/dev/null)
    if [ -z "$api_key" ]; then
        err "未找到 OPENAI_API_KEY"
        return 1
    fi

    # 读取 base_url
    local base_url=""
    if [ -f "$codex_config" ]; then
        base_url=$(grep -oP 'base_url\s*=\s*"\K[^"]+' "$codex_config" 2>/dev/null)
    fi
    base_url=${base_url:-"https://2api.cloud/v1"}

    echo -e "  ${CYAN}正在测试 Codex API 连接...${NC}"
    if command_exists curl; then
        response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" --max-time 10 "${base_url}/models" 2>/dev/null)
        http_code=$(echo "$response" | tail -n1)

        if [ "$http_code" = "200" ]; then
            info "Codex API 连接测试成功"
            return 0
        else
            err "Codex API 连接测试失败: HTTP $http_code"
            return 1
        fi
    else
        warn "未找到 curl，无法测试"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# 配置管理菜单
# ---------------------------------------------------------------------------
config_menu() {
    while true; do
        echo ""
        echo -e "  ${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${CYAN}║                   配置管理菜单                          ║${NC}"
        echo -e "  ${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "  [1] 查看配置文件"
        echo "  [2] 编辑配置文件"
        echo "  [3] 测试 API 连接"
        echo "  [4] 检查配置冲突"
        echo "  [5] 获取模型列表"
        echo "  [Q] 退出"
        echo ""

        read -rp "  请选择 [1-5/Q]: " menu_choice

        case "$menu_choice" in
            1)
                echo ""
                if [ -f "$SETTINGS_PATH" ]; then
                    echo -e "  ${CYAN}Claude Code 配置文件: $SETTINGS_PATH${NC}"
                    cat "$SETTINGS_PATH"
                else
                    warn "Claude Code 配置文件不存在"
                fi
                echo ""
                if [ -f "$HOME/.codex/auth.json" ]; then
                    echo -e "  ${CYAN}Codex auth.json: $HOME/.codex/auth.json${NC}"
                    cat "$HOME/.codex/auth.json"
                else
                    warn "Codex auth.json 不存在"
                fi
                echo ""
                if [ -f "$HOME/.codex/config.toml" ]; then
                    echo -e "  ${CYAN}Codex config.toml: $HOME/.codex/config.toml${NC}"
                    cat "$HOME/.codex/config.toml"
                else
                    warn "Codex config.toml 不存在"
                fi
                ;;
            2)
                echo ""
                echo "  选择要编辑的配置文件:"
                echo "  [1] Claude Code settings.json"
                echo "  [2] Codex auth.json"
                echo "  [3] Codex config.toml"
                echo ""
                read -rp "  请选择 [1-3]: " edit_choice

                case "$edit_choice" in
                    1)
                        if [ -f "$SETTINGS_PATH" ]; then
                            if command_exists code; then
                                code "$SETTINGS_PATH"
                            elif command_exists nano; then
                                nano "$SETTINGS_PATH"
                            elif command_exists vi; then
                                vi "$SETTINGS_PATH"
                            else
                                echo -e "  ${YELLOW}请手动编辑: $SETTINGS_PATH${NC}"
                            fi
                        else
                            warn "配置文件不存在"
                        fi
                        ;;
                    2)
                        if [ -f "$HOME/.codex/auth.json" ]; then
                            if command_exists code; then
                                code "$HOME/.codex/auth.json"
                            elif command_exists nano; then
                                nano "$HOME/.codex/auth.json"
                            elif command_exists vi; then
                                vi "$HOME/.codex/auth.json"
                            else
                                echo -e "  ${YELLOW}请手动编辑: $HOME/.codex/auth.json${NC}"
                            fi
                        else
                            warn "配置文件不存在"
                        fi
                        ;;
                    3)
                        if [ -f "$HOME/.codex/config.toml" ]; then
                            if command_exists code; then
                                code "$HOME/.codex/config.toml"
                            elif command_exists nano; then
                                nano "$HOME/.codex/config.toml"
                            elif command_exists vi; then
                                vi "$HOME/.codex/config.toml"
                            else
                                echo -e "  ${YELLOW}请手动编辑: $HOME/.codex/config.toml${NC}"
                            fi
                        else
                            warn "配置文件不存在"
                        fi
                        ;;
                esac
                ;;
            3)
                echo ""
                echo "  选择要测试的 API:"
                echo "  [1] Claude Code API"
                echo "  [2] Codex API"
                echo "  [3] 全部测试"
                echo ""
                read -rp "  请选择 [1-3]: " test_choice

                case "$test_choice" in
                    1|3)
                        if [ -f "$SETTINGS_PATH" ]; then
                            api_key=$(grep -oP '"ANTHROPIC_AUTH_TOKEN":\s*"\K[^"]+' "$SETTINGS_PATH" 2>/dev/null)
                            if [ -n "$api_key" ]; then
                                test_url="${DEFAULT_BASE_URL}v1/models"
                                echo -e "  ${CYAN}正在测试 Claude Code API...${NC}"
                                response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${api_key}" -H "Content-Type: application/json" --max-time 10 "$test_url" 2>/dev/null)
                                http_code=$(echo "$response" | tail -n1)
                                if [ "$http_code" = "200" ]; then
                                    info "Claude Code API 连接测试成功"
                                else
                                    err "Claude Code API 连接测试失败: HTTP $http_code"
                                fi
                            else
                                warn "未找到 Claude Code API 令牌"
                            fi
                        else
                            warn "Claude Code 配置文件不存在"
                        fi

                        if [ "$test_choice" = "3" ]; then
                            echo ""
                            test_codex_api
                        fi
                        ;;
                    2)
                        test_codex_api
                        ;;
                esac
                ;;
            4)
                check_config_conflicts
                ;;
            5)
                echo ""
                if [ -f "$SETTINGS_PATH" ]; then
                    api_key=$(grep -oP '"ANTHROPIC_AUTH_TOKEN":\s*"\K[^"]+' "$SETTINGS_PATH" 2>/dev/null)
                    if [ -n "$api_key" ]; then
                        fetch_models "$api_key"
                    else
                        warn "未找到 API 令牌"
                    fi
                else
                    warn "配置文件不存在"
                fi
                ;;
            Q|q)
                echo ""
                info "退出配置管理"
                break
                ;;
            *)
                warn "无效选择"
                ;;
        esac

        if [ "$menu_choice" != "Q" ] && [ "$menu_choice" != "q" ]; then
            echo ""
            read -rp "  按 Enter 继续..."
        fi
    done
}

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

# 提供配置管理菜单
echo ""
read -rp "  是否进入配置管理菜单? [y/N]: " enter_menu
if [ "$enter_menu" = "y" ] || [ "$enter_menu" = "Y" ]; then
    config_menu
fi

echo ""
info "安装完成！"
echo ""

