#!/usr/bin/env bash
# ============================================================================
# Claude Code API 配置工具 - 智谱 GLM / Anthropic 兼容 API (macOS / Linux)
# ============================================================================

set -e

TOKEN_URL="https://2api.cloud/console/token"
DEFAULT_BASE_URL="https://2api.cloud/"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_PATH="$SETTINGS_DIR/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m'

GLM_MODELS=("glm-5" "glm-4.7" "glm-4.5" "glm-4.7-flash" "glm-4-flash" "glm-4.5-air")
GLM_DESCS=(
    "旗舰模型 745B MoE，最强（对标 Claude Opus）"
    "编程增强 SWE-bench 73.8（对标 Claude Sonnet）"
    "Agent 基座，工具调用优化"
    "30B MoE 轻量快速（对标 Claude Haiku）"
    "免费模型，轻量任务"
    "轻量快速，低成本"
)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

open_url() {
    local url="$1"
    case "$(uname -s)" in
        Darwin*) open "$url" 2>/dev/null ;;
        Linux*)
            if command_exists xdg-open; then
                xdg-open "$url" 2>/dev/null
            else
                echo -e "  请手动打开: $url"
            fi
            ;;
    esac
}

mask_secret() {
    local value="$1"
    if [ -z "$value" ]; then
        echo "(未设置)"
    else
        echo "${value:0:8}****"
    fi
}

get_json_value() {
    local key="$1"
    if [ -f "$SETTINGS_PATH" ] && command_exists python3; then
        python3 -c "
import json, sys
try:
    with open('$SETTINGS_PATH') as f:
        d = json.load(f)
    print(d.get('env', {}).get('$key', ''))
except:
    pass
" 2>/dev/null
    elif [ -f "$SETTINGS_PATH" ]; then
        grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$SETTINGS_PATH" 2>/dev/null | sed 's/.*: *"//;s/"$//' || true
    fi
}

save_settings() {
    local base_url="$1"
    local api_key="$2"
    local opus_model="$3"
    local sonnet_model="$4"
    local haiku_model="$5"

    mkdir -p "$SETTINGS_DIR"

    if command_exists python3; then
        python3 -c "
import json, os

path = '$SETTINGS_PATH'
settings = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            settings = json.load(f)
    except:
        pass

if 'env' not in settings:
    settings['env'] = {}

settings['env']['ANTHROPIC_BASE_URL'] = '$base_url'
settings['env']['ANTHROPIC_API_KEY'] = '$api_key'
settings['env'].pop('ANTHROPIC_AUTH_TOKEN', None)

opus = '$opus_model'
sonnet = '$sonnet_model'
haiku = '$haiku_model'

for key, val in [('ANTHROPIC_DEFAULT_OPUS_MODEL', opus), ('ANTHROPIC_DEFAULT_SONNET_MODEL', sonnet), ('ANTHROPIC_DEFAULT_HAIKU_MODEL', haiku)]:
    if val:
        settings['env'][key] = val
    else:
        settings['env'].pop(key, None)

with open(path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"
    else
        if [ -z "$opus_model" ] && [ -z "$sonnet_model" ] && [ -z "$haiku_model" ]; then
            cat > "$SETTINGS_PATH" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$base_url",
    "ANTHROPIC_API_KEY": "$api_key"
  }
}
EOF
        else
            cat > "$SETTINGS_PATH" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$base_url",
    "ANTHROPIC_API_KEY": "$api_key",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$haiku_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$sonnet_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$opus_model"
  }
}
EOF
        fi
    fi
}

clear_settings() {
    if [ ! -f "$SETTINGS_PATH" ]; then
        echo -e "  ${GRAY}[信息] 无配置文件，无需清除。${NC}"
        return
    fi

    if command_exists python3; then
        python3 -c "
import json

path = '$SETTINGS_PATH'
with open(path) as f:
    settings = json.load(f)

keys = ['ANTHROPIC_BASE_URL', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL',
        'ANTHROPIC_DEFAULT_OPUS_MODEL']

for k in keys:
    settings.get('env', {}).pop(k, None)

with open(path, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
"
    else
        rm -f "$SETTINGS_PATH"
    fi
    echo -e "  ${GREEN}[信息] Claude Code API 配置已清除。${NC}"
}

show_current_config() {
    echo ""
    echo -e "  ${CYAN}当前 API 配置:${NC}"
    echo -e "  ${GRAY}----------------------------------------${NC}"

    if [ ! -f "$SETTINGS_PATH" ]; then
        echo -e "    ${GRAY}(尚未配置)${NC}"
        echo -e "  ${GRAY}----------------------------------------${NC}"
        echo ""
        return
    fi

    local base_url api_key opus sonnet haiku
    base_url=$(get_json_value "ANTHROPIC_BASE_URL")
    api_key=$(get_json_value "ANTHROPIC_API_KEY")
    opus=$(get_json_value "ANTHROPIC_DEFAULT_OPUS_MODEL")
    sonnet=$(get_json_value "ANTHROPIC_DEFAULT_SONNET_MODEL")
    haiku=$(get_json_value "ANTHROPIC_DEFAULT_HAIKU_MODEL")

    echo "    ANTHROPIC_BASE_URL             = $base_url"
    echo "    ANTHROPIC_API_KEY              = $(mask_secret "$api_key")"
    echo "    ANTHROPIC_DEFAULT_OPUS_MODEL   = $opus"
    echo "    ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnet"
    echo "    ANTHROPIC_DEFAULT_HAIKU_MODEL  = $haiku"

    echo -e "  ${GRAY}----------------------------------------${NC}"
    echo ""
}

select_model() {
    local title="$1"
    local default_index="$2"

    echo ""
    echo -e "  $title"

    for i in "${!GLM_MODELS[@]}"; do
        local tag=""
        if [ "$i" -eq "$default_index" ]; then
            tag="  <- 推荐"
        fi
        echo "    [$((i + 1))] ${GLM_MODELS[$i]} - ${GLM_DESCS[$i]}$tag"
    done

    read -rp "  请选择 (默认 $((default_index + 1))): " choice

    if [ -z "$choice" ]; then
        echo "${GLM_MODELS[$default_index]}"
        return
    fi

    local idx=$((choice - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#GLM_MODELS[@]}" ]; then
        echo "${GLM_MODELS[$default_index]}"
        return
    fi

    echo "${GLM_MODELS[$idx]}"
}

test_api_connection() {
    echo ""
    echo -e "  ${CYAN}正在测试 API 连接...${NC}"

    if [ ! -f "$SETTINGS_PATH" ]; then
        echo -e "  ${RED}[错误] 未找到配置文件，请先配置令牌。${NC}"
        return
    fi

    local base_url api_key model
    base_url=$(get_json_value "ANTHROPIC_BASE_URL")
    api_key=$(get_json_value "ANTHROPIC_API_KEY")
    model=$(get_json_value "ANTHROPIC_DEFAULT_SONNET_MODEL")

    [ -z "$base_url" ] && base_url="$DEFAULT_BASE_URL"
    [ -z "$model" ] && model="glm-4.7"

    if [ -z "$api_key" ]; then
        echo -e "  ${RED}[错误] 配置文件中未找到令牌。${NC}"
        return
    fi

    local test_url="${base_url%/}/v1/messages"
    local body='{"model":"'"$model"'","max_tokens":20,"messages":[{"role":"user","content":"请回复：连接成功"}]}'

    echo -e "  ${GRAY}请求地址: $test_url${NC}"
    echo -e "  ${GRAY}使用模型: $model${NC}"

    if ! command_exists curl; then
        echo -e "  ${RED}[错误] 未找到 curl 命令${NC}"
        return
    fi

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "x-api-key: $api_key" \
        -H "Authorization: Bearer $api_key" \
        -d "$body" \
        --connect-timeout 15 \
        --max-time 30 2>/dev/null) || true

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body_response
    body_response=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        echo ""
        echo -e "  ${GREEN}[成功] API 连接正常!${NC}"
        if command_exists python3; then
            local reply
            reply=$(python3 -c "
import json, sys
try:
    d = json.loads('''$body_response''')
    print(d['content'][0]['text'])
except:
    print('(解析回复失败)')
" 2>/dev/null)
            echo -e "  ${GREEN}模型回复: $reply${NC}"
        else
            echo -e "  ${GREEN}HTTP 200 - 连接成功${NC}"
        fi
    else
        echo ""
        echo -e "  ${RED}[错误] API 连接失败 (HTTP $http_code)${NC}"
        echo -e "  ${GRAY}响应: $body_response${NC}"
        echo ""
        echo -e "  ${YELLOW}请检查令牌、账户余额、网络连接。${NC}"
    fi
}

# ---------------------------------------------------------------------------
# 主菜单循环
# ---------------------------------------------------------------------------
while true; do
    clear
    echo ""
    echo -e "  ${MAGENTA}================================================================${NC}"
    echo -e "  ${MAGENTA}     Claude Code API 配置工具 - 智谱 GLM${NC}"
    echo -e "  ${MAGENTA}================================================================${NC}"

    show_current_config

    echo "  请选择操作:"
    echo "    [1] 配置智谱 GLM 令牌"
    echo "    [2] 清除 API 配置"
    echo "    [3] 测试当前 API 连接"
    echo "    [4] 配置自定义 Anthropic 兼容 API"
    echo "    [Q] 退出"
    echo ""

    read -rp "  请输入选项: " choice

    case "$choice" in
        [Qq])
            echo ""
            echo -e "  ${YELLOW}配置工具已退出。请打开新的终端窗口使配置生效。${NC}"
            echo ""
            break
            ;;
        1)
            echo ""
            echo -e "  ${GRAY}获取令牌: $TOKEN_URL${NC}"
            read -rp "  是否打开浏览器获取令牌? (Y/n): " open_browser
            if [ "$open_browser" != "n" ] && [ "$open_browser" != "N" ]; then
                open_url "$TOKEN_URL"
            fi

            read -rp "  请输入令牌: " api_key
            if [ -z "$api_key" ]; then
                echo -e "  ${YELLOW}[警告] 未输入令牌，操作取消。${NC}"
                read -rp "  按 Enter 返回主菜单"
                continue
            fi

            echo ""
            echo "  选择模型 (留空使用服务默认):"
            echo "    [0] 不指定模型，使用服务默认  <- 推荐"
            for i in "${!GLM_MODELS[@]}"; do
                echo "    [$((i + 1))] ${GLM_MODELS[$i]} - ${GLM_DESCS[$i]}"
            done
            read -rp "  请选择 (默认 0): " model_choice
            model_choice=${model_choice:-0}

            if [ "$model_choice" = "0" ]; then
                save_settings "$DEFAULT_BASE_URL" "$api_key" "" "" ""
                echo ""
                echo -e "  ${GREEN}[成功] 配置完成!${NC}"
                echo -e "  ${GREEN}模型: 使用服务默认${NC}"
            else
                local idx=$((model_choice - 1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#GLM_MODELS[@]}" ]; then
                    local selected="${GLM_MODELS[$idx]}"
                    save_settings "$DEFAULT_BASE_URL" "$api_key" "$selected" "$selected" "$selected"
                    echo ""
                    echo -e "  ${GREEN}[成功] 配置完成!${NC}"
                    echo -e "  ${GREEN}模型: $selected${NC}"
                else
                    save_settings "$DEFAULT_BASE_URL" "$api_key" "" "" ""
                    echo ""
                    echo -e "  ${GREEN}[成功] 配置完成!${NC}"
                    echo -e "  ${GREEN}模型: 使用服务默认${NC}"
                fi
            fi
            echo -e "  ${GRAY}配置已写入: $SETTINGS_PATH${NC}"
            read -rp "  按 Enter 返回主菜单"
            ;;
        2)
            read -rp "  确定要清除 API 配置吗? (y/N): " confirm_clear
            if [ "$confirm_clear" = "y" ] || [ "$confirm_clear" = "Y" ]; then
                clear_settings
            fi
            read -rp "  按 Enter 返回主菜单"
            ;;
        3)
            test_api_connection
            echo ""
            read -rp "  按 Enter 返回主菜单"
            ;;
        4)
            echo ""
            echo -e "  ${CYAN}配置自定义 Anthropic 兼容 API${NC}"
            echo -e "  ${GRAY}适用于其他中转服务商或自建网关，前提是它提供 /v1/messages 格式。${NC}"
            echo -e "  ${YELLOW}只支持 OpenAI 格式 (/v1/chat/completions) 的服务商不能直接使用。${NC}"
            echo ""

            read -rp "  请输入 API Base URL (例如 https://your-provider.com/anthropic): " base_url
            if [ -z "$base_url" ]; then
                echo -e "  ${YELLOW}[警告] 未输入 Base URL，操作取消。${NC}"
                read -rp "  按 Enter 返回主菜单"
                continue
            fi
            base_url="${base_url%/}"

            read -rp "  请输入令牌: " api_key
            if [ -z "$api_key" ]; then
                echo -e "  ${YELLOW}[警告] 未输入令牌，操作取消。${NC}"
                read -rp "  按 Enter 返回主菜单"
                continue
            fi

            echo ""
            echo "  请填写模型名（全部留空则使用服务默认模型）。"
            echo -e "  ${GRAY}Opus = 主力/复杂任务，Sonnet = 日常，Haiku = 轻量/快速。${NC}"

            read -rp "  Opus 模型名（主力，留空使用默认）: " opus_model

            read -rp "  Sonnet 模型名（日常，留空则使用 Opus 模型）: " sonnet_model
            [ -z "$sonnet_model" ] && sonnet_model="$opus_model"

            read -rp "  Haiku 模型名（轻量，留空则使用 Sonnet 模型）: " haiku_model
            [ -z "$haiku_model" ] && haiku_model="$sonnet_model"

            save_settings "$base_url" "$api_key" "$opus_model" "$sonnet_model" "$haiku_model"

            echo ""
            echo -e "  ${GREEN}[成功] 自定义 API 配置完成!${NC}"
            echo -e "  ${GREEN}Base URL:    $base_url${NC}"
            echo -e "  ${GREEN}Opus 模型:   $opus_model${NC}"
            echo -e "  ${GREEN}Sonnet 模型: $sonnet_model${NC}"
            echo -e "  ${GREEN}Haiku 模型:  $haiku_model${NC}"
            echo -e "  ${GRAY}配置已写入: $SETTINGS_PATH${NC}"
            read -rp "  按 Enter 返回主菜单"
            ;;
        *)
            echo -e "  ${YELLOW}无效选项，请重试。${NC}"
            sleep 1
            ;;
    esac
done
