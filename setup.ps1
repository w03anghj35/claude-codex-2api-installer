# ============================================================================
# Claude Code 一键安装脚本 (Windows) - 单文件自包含版
# 面向中国用户 - 支持国产大模型 API
#
# 使用方式 (复制粘贴到 PowerShell 即可):
#   irm https://raw.githubusercontent.com/你的用户名/claude-code-cn-installer/main/setup.ps1 | iex
#
# 或者先下载再运行:
#   Invoke-WebRequest -Uri "上面的地址" -OutFile setup.ps1
#   powershell -ExecutionPolicy Bypass -File setup.ps1
# ============================================================================

#Requires -RunAsAdministrator

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# 全局配置
# ---------------------------------------------------------------------------
$NODEJS_VERSION   = "22.13.1"
$NODEJS_URL       = "https://npmmirror.com/mirrors/node/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-x64.msi"
$GIT_VERSION      = "2.47.1"
$GIT_URL          = "https://registry.npmmirror.com/-/binary/git-for-windows/v${GIT_VERSION}.windows.1/Git-${GIT_VERSION}-64-bit.exe"
$NPM_MIRROR       = "https://registry.npmmirror.com"
$SETTINGS_DIR     = "$env:USERPROFILE\.claude"
$SETTINGS_PATH    = "$SETTINGS_DIR\settings.json"
$DEFAULT_BASE_URL = "https://2api.cloud/"
$TOKEN_URL        = "https://2api.cloud/console/token"

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------
function Info  { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green }
function Warn  { param([string]$M) Write-Host "  [!]  $M" -ForegroundColor Yellow }
function Err   { param([string]$M) Write-Host "  [X]  $M" -ForegroundColor Red }
function Step  { param([string]$M) Write-Host ""; Write-Host "  > $M" -ForegroundColor Cyan; Write-Host "" }

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
}

function Test-Cmd { param([string]$C) $null -ne (Get-Command $C -ErrorAction SilentlyContinue) }

function Download-File {
    param([string]$Url, [string]$OutFile, [string]$Desc)
    Info "正在下载 $Desc ..."
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 300
        $ProgressPreference = 'Continue'
        return $true
    } catch {
        try {
            (New-Object System.Net.WebClient).DownloadFile($Url, $OutFile)
            return $true
        } catch {
            Err "$Desc 下载失败: $_"
            return $false
        }
    }
}

# ---------------------------------------------------------------------------
# 欢迎
# ---------------------------------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  +--------------------------------------------------------+" -ForegroundColor Magenta
Write-Host "  |      Claude Code 一键安装 (Windows 中国版)             |" -ForegroundColor Magenta
Write-Host "  +--------------------------------------------------------+" -ForegroundColor Magenta
Write-Host ""
Write-Host "  本脚本将自动完成:"
Write-Host "    1. 安装 Node.js (国内镜像)"
Write-Host "    2. 安装 Git (国内镜像)"
Write-Host "    3. 配置 npm 国内镜像源"
Write-Host "    4. 安装 Claude Code"
Write-Host "    5. 配置 API 令牌"
Write-Host ""

$confirm = Read-Host "  按 Enter 开始安装，输入 Q 退出"
if ($confirm -eq 'Q' -or $confirm -eq 'q') {
    Write-Host "  已取消。" -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# 步骤 1: Node.js
# ---------------------------------------------------------------------------
Step "步骤 1/5: 检查 Node.js"

$skipNode = $false
if (Test-Cmd "node") {
    $nodeVer = & node --version 2>$null
    $major = [int]($nodeVer -replace 'v(\d+)\..*', '$1')
    if ($major -ge 18 -and (Test-Cmd "npm")) {
        Info "Node.js $nodeVer 已安装，版本满足要求"
        $skipNode = $true
    } else {
        Warn "Node.js 版本过低或 npm 缺失，将安装新版本"
    }
}

if (-not $skipNode) {
    $nodeMsi = "$env:TEMP\nodejs-installer.msi"
    if (Download-File -Url $NODEJS_URL -OutFile $nodeMsi -Desc "Node.js v${NODEJS_VERSION}") {
        Info "正在安装 Node.js (静默安装)..."
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait -PassThru
        if ($p.ExitCode -eq 0) { Info "Node.js 安装成功" }
        else { Err "Node.js 安装失败 (代码: $($p.ExitCode))" }
        Remove-Item -Path $nodeMsi -Force -ErrorAction SilentlyContinue
    }
    Refresh-Path
}

# ---------------------------------------------------------------------------
# 步骤 2: Git
# ---------------------------------------------------------------------------
Step "步骤 2/5: 检查 Git"

if (Test-Cmd "git") {
    Info "$(& git --version 2>$null) 已安装"
} else {
    $gitExe = "$env:TEMP\git-installer.exe"
    if (Download-File -Url $GIT_URL -OutFile $gitExe -Desc "Git v${GIT_VERSION}") {
        Info "正在安装 Git (静默安装)..."
        $p = Start-Process -FilePath $gitExe -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS" -Wait -PassThru
        if ($p.ExitCode -eq 0) { Info "Git 安装成功" }
        else { Err "Git 安装失败 (代码: $($p.ExitCode))" }
        Remove-Item -Path $gitExe -Force -ErrorAction SilentlyContinue
    }
    Refresh-Path
}

# ---------------------------------------------------------------------------
# 步骤 3: npm 镜像
# ---------------------------------------------------------------------------
Step "步骤 3/5: 配置 npm 国内镜像源"

if (Test-Cmd "npm") {
    & npm config set registry $NPM_MIRROR 2>$null
    Info "npm 镜像源已设置为: $NPM_MIRROR"
} else {
    Err "npm 未找到，请确保 Node.js 安装成功"
}

# ---------------------------------------------------------------------------
# 步骤 4: Claude Code
# ---------------------------------------------------------------------------
Step "步骤 4/5: 安装 Claude Code"

if (Test-Cmd "claude") {
    Info "Claude Code $(& claude --version 2>$null) 已安装"
} elseif (Test-Cmd "npm") {
    Info "正在安装 Claude Code (使用国内镜像，请稍候)..."
    & npm install -g @anthropic-ai/claude-code 2>&1 | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Refresh-Path
    if (Test-Cmd "claude") { Info "Claude Code 安装成功" }
    else { Warn "安装完成，但需要重启终端才能使用 claude 命令" }
} else {
    Err "npm 不可用，无法安装 Claude Code"
}

# ---------------------------------------------------------------------------
# 步骤 5: 配置 API
# ---------------------------------------------------------------------------
Step "步骤 5/5: 配置 API 令牌"

Write-Host ""
Write-Host "  Claude Code 需要一个 API 令牌才能运行。"
Write-Host "  获取令牌: $TOKEN_URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "  可用模型:"
Write-Host "    [1] glm-5         - 旗舰模型，最强 (推荐)"
Write-Host "    [2] glm-4.7       - 编程增强，日常使用"
Write-Host "    [3] glm-4.5       - Agent 基座"
Write-Host "    [4] glm-4.7-flash - 轻量快速"
Write-Host "    [5] glm-4-flash   - 免费模型"
Write-Host "    [6] 跳过，稍后手动配置"
Write-Host ""

$glmModels = @("glm-5", "glm-4.7", "glm-4.5", "glm-4.7-flash", "glm-4-flash")
$modelChoice = Read-Host "  请选择模型 [1-6] (默认 1)"
if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "1" }

if ($modelChoice -ge "1" -and $modelChoice -le "5") {
    Write-Host ""
    $openBrowser = Read-Host "  是否打开浏览器获取令牌? [Y/n]"
    if ($openBrowser -ne 'n' -and $openBrowser -ne 'N') {
        Start-Process $TOKEN_URL
        Info "已打开浏览器，如未打开请手动访问上面的地址"
        Write-Host ""
    }

    $apiKey = Read-Host "  请粘贴你的令牌"

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Warn "未输入令牌，跳过配置"
        Warn "稍后可重新运行本脚本配置"
    } else {
        $idx = [int]$modelChoice - 1
        $opusModel = $glmModels[$idx]
        $sonnetModel = if ($idx -le 1) { "glm-4.7" } else { $glmModels[$idx] }
        $haikuModel = "glm-4.5-air"

        if (-not (Test-Path $SETTINGS_DIR)) {
            New-Item -ItemType Directory -Path $SETTINGS_DIR -Force | Out-Null
        }

        $settingsObj = [ordered]@{
            env = [ordered]@{
                ANTHROPIC_BASE_URL             = $DEFAULT_BASE_URL
                ANTHROPIC_API_KEY              = $apiKey
                ANTHROPIC_DEFAULT_OPUS_MODEL   = $opusModel
                ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnetModel
                ANTHROPIC_DEFAULT_HAIKU_MODEL  = $haikuModel
            }
        }
        $settingsObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $SETTINGS_PATH -Encoding UTF8 -Force

        Write-Host ""
        Info "配置完成!"
        Info "  主力模型: $opusModel"
        Info "  日常模型: $sonnetModel"
        Info "  轻量模型: $haikuModel"
    }
} else {
    Info "跳过 API 配置，稍后可重新运行本脚本"
}

# ---------------------------------------------------------------------------
# 完成
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  +--------------------------------------------------------+" -ForegroundColor Green
Write-Host "  |                    安装完成!                            |" -ForegroundColor Green
Write-Host "  +--------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  现在打开一个新的终端窗口，运行:"
Write-Host ""
Write-Host "    claude" -ForegroundColor Cyan
Write-Host ""
Write-Host "  测试连接:"
Write-Host ""
Write-Host "    claude -p `"你好`" --output-format text" -ForegroundColor Cyan
Write-Host ""

# 状态检测
Write-Host "  安装状态:"
Refresh-Path
if (Test-Cmd "node")   { Info "Node.js $(& node --version 2>$null)" } else { Err "Node.js 未检测到" }
if (Test-Cmd "git")    { Info "$(& git --version 2>$null)" }          else { Err "Git 未检测到" }
if (Test-Cmd "claude") { Info "Claude Code 已就绪" }                  else { Warn "Claude Code 需重启终端" }
if ((Test-Path $SETTINGS_PATH) -and (Select-String -Path $SETTINGS_PATH -Pattern "ANTHROPIC_API_KEY" -Quiet)) {
    Info "API 令牌已配置"
} else {
    Warn "API 令牌未配置"
}

Write-Host ""
Read-Host "  按 Enter 退出"
