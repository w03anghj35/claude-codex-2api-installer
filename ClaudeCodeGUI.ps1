# ============================================================================
# Claude Code / Codex 图形安装配置助手
# 流程与 setup.ps1 一致
# ============================================================================

Set-ExecutionPolicy Bypass -Scope Process -Force

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$IS_ADMIN = Test-IsAdmin

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

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
$DEFAULT_BASE_URL = "https://2api.cloud"
$TOKEN_URL        = "https://2api.cloud/console/token"
$CODEX_HOME       = "$env:USERPROFILE\.codex"

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------
function Remove-BOM {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $content = Get-Content -Path $FilePath -Raw
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)
    }
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = "$machinePath;$userPath"
}

function Test-Cmd { param([string]$C) $null -ne (Get-Command $C -ErrorAction SilentlyContinue) }

function Download-File {
    param([string]$Url, [string]$OutFile, [string]$Desc, [System.Windows.Forms.TextBox]$Log)
    Add-Log $Log "正在下载 $Desc ..."
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
            Add-Log $Log "[错误] $Desc 下载失败: $_"
            return $false
        }
    }
}

function Add-Log {
    param([System.Windows.Forms.TextBox]$Box, [string]$Msg)
    $time = Get-Date -Format "HH:mm:ss"
    $Box.AppendText("[$time] $Msg`r`n")
    $Box.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Save-ClaudeConfig {
    param([string]$ApiKey, [string]$Model)
    if (-not (Test-Path $SETTINGS_DIR)) {
        New-Item -ItemType Directory -Path $SETTINGS_DIR -Force | Out-Null
    }
    # 清理冲突的环境变量（仅用户级，避免需要管理员权限）
    try {
        [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $null, "User")
        $env:ANTHROPIC_API_KEY = $null
    } catch {}

    if ([string]::IsNullOrWhiteSpace($Model)) {
        $obj = [ordered]@{
            env = [ordered]@{
                ANTHROPIC_AUTH_TOKEN = $ApiKey
                ANTHROPIC_BASE_URL   = $DEFAULT_BASE_URL
            }
        }
    } else {
        $obj = [ordered]@{
            env = [ordered]@{
                ANTHROPIC_AUTH_TOKEN           = $ApiKey
                ANTHROPIC_BASE_URL             = $DEFAULT_BASE_URL
                ANTHROPIC_DEFAULT_OPUS_MODEL   = $Model
                ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
                ANTHROPIC_DEFAULT_HAIKU_MODEL  = $Model
                ANTHROPIC_MODEL                = $Model
            }
        }
    }
    $obj | ConvertTo-Json -Depth 5 | Out-File -FilePath $SETTINGS_PATH -Encoding UTF8 -Force
}

function Save-CodexConfig {
    param([string]$ApiKey, [string]$Model)
    if (-not (Test-Path $CODEX_HOME)) {
        New-Item -ItemType Directory -Path $CODEX_HOME -Force | Out-Null
    }
    [ordered]@{ OPENAI_API_KEY = $ApiKey } | ConvertTo-Json -Depth 5 | Out-File -FilePath "$CODEX_HOME\auth.json" -Encoding UTF8 -Force

    $cfg = "model_provider = `"88code`"`r`n"
    if (-not [string]::IsNullOrWhiteSpace($Model)) { $cfg += "model = `"$Model`"`r`n" }
    $cfg += "`r`n[model_providers.88code]`r`nname = `"88code`"`r`nbase_url = `"$DEFAULT_BASE_URL/v1`"`r`nwire_api = `"responses`"`r`nrequires_openai_auth = true`r`n"
    $cfg | Out-File -FilePath "$CODEX_HOME\config.toml" -Encoding UTF8 -Force
}

# ---------------------------------------------------------------------------
# 主窗口
# ---------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Claude Code / Codex 安装配置助手"
$form.StartPosition = "CenterScreen"
$form.Size          = New-Object System.Drawing.Size(780, 680)
$form.MinimumSize   = New-Object System.Drawing.Size(780, 680)
$form.Font          = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

# 标题
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text     = "Claude Code / Codex 安装配置助手"
$lblTitle.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 16)
$lblTitle.Size     = New-Object System.Drawing.Size(600, 30)
$form.Controls.Add($lblTitle)

# ---------------------------------------------------------------------------
# 步骤 0: 模式选择
# ---------------------------------------------------------------------------
$grpMode = New-Object System.Windows.Forms.GroupBox
$grpMode.Text     = "模式选择"
$grpMode.Location = New-Object System.Drawing.Point(20, 56)
$grpMode.Size     = New-Object System.Drawing.Size(730, 56)
$form.Controls.Add($grpMode)

$rbFull = New-Object System.Windows.Forms.RadioButton
$rbFull.Text     = "完整安装 (Node.js + Git + Claude Code + 配置 API)"
$rbFull.Location = New-Object System.Drawing.Point(16, 22)
$rbFull.Size     = New-Object System.Drawing.Size(340, 22)
$rbFull.Checked  = $true
$grpMode.Controls.Add($rbFull)

$rbApiOnly = New-Object System.Windows.Forms.RadioButton
$rbApiOnly.Text     = "仅配置 / 更换 API 令牌"
$rbApiOnly.Location = New-Object System.Drawing.Point(370, 22)
$rbApiOnly.Size     = New-Object System.Drawing.Size(220, 22)
$grpMode.Controls.Add($rbApiOnly)

# ---------------------------------------------------------------------------
# 步骤 1: 工具选择
# ---------------------------------------------------------------------------
$grpTool = New-Object System.Windows.Forms.GroupBox
$grpTool.Text     = "步骤 1 — 选择要安装的工具"
$grpTool.Location = New-Object System.Drawing.Point(20, 122)
$grpTool.Size     = New-Object System.Drawing.Size(730, 56)
$form.Controls.Add($grpTool)

$rbClaude = New-Object System.Windows.Forms.RadioButton
$rbClaude.Text     = "Claude Code (推荐)"
$rbClaude.Location = New-Object System.Drawing.Point(16, 22)
$rbClaude.Size     = New-Object System.Drawing.Size(160, 22)
$rbClaude.Checked  = $true
$grpTool.Controls.Add($rbClaude)

$rbCodex = New-Object System.Windows.Forms.RadioButton
$rbCodex.Text     = "Codex"
$rbCodex.Location = New-Object System.Drawing.Point(190, 22)
$rbCodex.Size     = New-Object System.Drawing.Size(100, 22)
$grpTool.Controls.Add($rbCodex)

$rbBoth = New-Object System.Windows.Forms.RadioButton
$rbBoth.Text     = "两个都装"
$rbBoth.Location = New-Object System.Drawing.Point(300, 22)
$rbBoth.Size     = New-Object System.Drawing.Size(120, 22)
$grpTool.Controls.Add($rbBoth)

# ---------------------------------------------------------------------------
# 步骤 2: 安装环境
# ---------------------------------------------------------------------------
$grpInstall = New-Object System.Windows.Forms.GroupBox
$grpInstall.Text     = "步骤 2 — 安装环境 (Node.js / Git / Claude Code / Codex)"
$grpInstall.Location = New-Object System.Drawing.Point(20, 188)
$grpInstall.Size     = New-Object System.Drawing.Size(730, 60)
$form.Controls.Add($grpInstall)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text     = "开始安装"
$btnInstall.Location = New-Object System.Drawing.Point(16, 20)
$btnInstall.Size     = New-Object System.Drawing.Size(120, 30)
$grpInstall.Controls.Add($btnInstall)

$lblInstallHint = New-Object System.Windows.Forms.Label
$lblInstallHint.Text     = "检测已安装的组件，只安装缺失项。仅配置模式下此步骤跳过。"
$lblInstallHint.Location = New-Object System.Drawing.Point(150, 26)
$lblInstallHint.Size     = New-Object System.Drawing.Size(560, 20)
$grpInstall.Controls.Add($lblInstallHint)

# ---------------------------------------------------------------------------
# 步骤 3: 配置 API
# ---------------------------------------------------------------------------
$grpApi = New-Object System.Windows.Forms.GroupBox
$grpApi.Text     = "步骤 3 — 配置 API 令牌"
$grpApi.Location = New-Object System.Drawing.Point(20, 260)
$grpApi.Size     = New-Object System.Drawing.Size(730, 160)
$form.Controls.Add($grpApi)

$btnOpenToken = New-Object System.Windows.Forms.Button
$btnOpenToken.Text     = "打开令牌页面"
$btnOpenToken.Location = New-Object System.Drawing.Point(16, 24)
$btnOpenToken.Size     = New-Object System.Drawing.Size(130, 30)
$grpApi.Controls.Add($btnOpenToken)

$lblTokenUrl = New-Object System.Windows.Forms.Label
$lblTokenUrl.Text      = $TOKEN_URL
$lblTokenUrl.ForeColor = [System.Drawing.Color]::Blue
$lblTokenUrl.Location  = New-Object System.Drawing.Point(158, 30)
$lblTokenUrl.Size      = New-Object System.Drawing.Size(540, 20)
$grpApi.Controls.Add($lblTokenUrl)

$lblToken = New-Object System.Windows.Forms.Label
$lblToken.Text     = "令牌:"
$lblToken.Location = New-Object System.Drawing.Point(16, 70)
$lblToken.Size     = New-Object System.Drawing.Size(50, 24)
$grpApi.Controls.Add($lblToken)

$txtToken = New-Object System.Windows.Forms.TextBox
$txtToken.Location     = New-Object System.Drawing.Point(70, 68)
$txtToken.Size         = New-Object System.Drawing.Size(480, 26)
$txtToken.PasswordChar = "*"
$grpApi.Controls.Add($txtToken)

$chkShow = New-Object System.Windows.Forms.CheckBox
$chkShow.Text     = "显示"
$chkShow.Location = New-Object System.Drawing.Point(562, 68)
$chkShow.Size     = New-Object System.Drawing.Size(60, 24)
$grpApi.Controls.Add($chkShow)

$lblModel = New-Object System.Windows.Forms.Label
$lblModel.Text     = "模型名:"
$lblModel.Location = New-Object System.Drawing.Point(16, 110)
$lblModel.Size     = New-Object System.Drawing.Size(54, 24)
$grpApi.Controls.Add($lblModel)

$txtModel = New-Object System.Windows.Forms.TextBox
$txtModel.Location    = New-Object System.Drawing.Point(70, 108)
$txtModel.Size        = New-Object System.Drawing.Size(300, 26)
$txtModel.ForeColor   = [System.Drawing.Color]::Gray
$txtModel.Text        = "留空使用服务默认（推荐）"
$grpApi.Controls.Add($txtModel)

$btnConfigure = New-Object System.Windows.Forms.Button
$btnConfigure.Text     = "写入配置"
$btnConfigure.Location = New-Object System.Drawing.Point(390, 106)
$btnConfigure.Size     = New-Object System.Drawing.Size(100, 30)
$grpApi.Controls.Add($btnConfigure)

$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text     = "测试连接"
$btnTest.Location = New-Object System.Drawing.Point(504, 106)
$btnTest.Size     = New-Object System.Drawing.Size(100, 30)
$grpApi.Controls.Add($btnTest)

# ---------------------------------------------------------------------------
# 状态日志
# ---------------------------------------------------------------------------
$grpLog = New-Object System.Windows.Forms.GroupBox
$grpLog.Text     = "状态日志"
$grpLog.Location = New-Object System.Drawing.Point(20, 432)
$grpLog.Size     = New-Object System.Drawing.Size(730, 190)
$form.Controls.Add($grpLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location   = New-Object System.Drawing.Point(10, 22)
$txtLog.Size       = New-Object System.Drawing.Size(708, 156)
$txtLog.Multiline  = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly   = $true
$txtLog.Font       = New-Object System.Drawing.Font("Consolas", 8.5)
$grpLog.Controls.Add($txtLog)

# ---------------------------------------------------------------------------
# 事件: 模式切换
# ---------------------------------------------------------------------------
$rbFull.Add_CheckedChanged({
    $grpInstall.Enabled = $rbFull.Checked
    $grpTool.Enabled    = $rbFull.Checked
})
$rbApiOnly.Add_CheckedChanged({
    $grpInstall.Enabled = $rbFull.Checked
    $grpTool.Enabled    = $rbFull.Checked
})

# ---------------------------------------------------------------------------
# 事件: 显示令牌
# ---------------------------------------------------------------------------
$chkShow.Add_CheckedChanged({
    $txtToken.PasswordChar = if ($chkShow.Checked) { [char]0 } else { "*" }
})

# ---------------------------------------------------------------------------
# 事件: 打开令牌页面
# ---------------------------------------------------------------------------
$btnOpenToken.Add_Click({
    Start-Process $TOKEN_URL
    Add-Log $txtLog "已打开浏览器: $TOKEN_URL"
})

# ---------------------------------------------------------------------------
# 事件: 开始安装
# ---------------------------------------------------------------------------
$btnInstall.Add_Click({
    # 检查管理员权限
    if (-not $IS_ADMIN) {
        [System.Windows.Forms.MessageBox]::Show(
            "安装 Node.js 和 Git 需要管理员权限。`n`n请以管理员身份重新运行本程序，或者选择「仅配置 API」模式。",
            "需要管理员权限",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $btnInstall.Enabled = $false
    $installClaude = $rbClaude.Checked -or $rbBoth.Checked
    $installCodex  = $rbCodex.Checked  -or $rbBoth.Checked

    try {
        # Node.js
        Add-Log $txtLog "--- 检查 Node.js ---"
        $skipNode = $false
        if (Test-Cmd "node") {
            $ver   = & node --version 2>$null
            $major = [int]($ver -replace 'v(\d+)\..*','$1')
            if ($major -ge 18 -and (Test-Cmd "npm")) {
                Add-Log $txtLog "Node.js $ver 已安装，跳过。"
                $skipNode = $true
            }
        }
        if (-not $skipNode) {
            $msi = "$env:TEMP\nodejs-installer.msi"
            if (Download-File -Url $NODEJS_URL -OutFile $msi -Desc "Node.js v${NODEJS_VERSION}" -Log $txtLog) {
                Add-Log $txtLog "正在安装 Node.js..."
                $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
                if ($p.ExitCode -eq 0) { Add-Log $txtLog "Node.js 安装成功。" }
                else { Add-Log $txtLog "[错误] Node.js 安装失败 (代码: $($p.ExitCode))" }
                Remove-Item $msi -Force -ErrorAction SilentlyContinue
            }
            Refresh-Path
        }

        # Git
        Add-Log $txtLog "--- 检查 Git ---"
        if (Test-Cmd "git") {
            Add-Log $txtLog "$(& git --version 2>$null) 已安装，跳过。"
        } else {
            $exe = "$env:TEMP\git-installer.exe"
            if (Download-File -Url $GIT_URL -OutFile $exe -Desc "Git v${GIT_VERSION}" -Log $txtLog) {
                Add-Log $txtLog "正在安装 Git..."
                $p = Start-Process $exe -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS" -Wait -PassThru
                if ($p.ExitCode -eq 0) { Add-Log $txtLog "Git 安装成功。" }
                else { Add-Log $txtLog "[错误] Git 安装失败 (代码: $($p.ExitCode))" }
                Remove-Item $exe -Force -ErrorAction SilentlyContinue
            }
            Refresh-Path
        }

        # npm 镜像
        if (Test-Cmd "npm") {
            & npm config set registry $NPM_MIRROR 2>$null
            Add-Log $txtLog "npm 镜像源已设置: $NPM_MIRROR"
        }

        # Claude Code
        if ($installClaude) {
            Add-Log $txtLog "--- 安装 Claude Code ---"
            if (Test-Cmd "claude") {
                Add-Log $txtLog "Claude Code $(& claude --version 2>$null) 已安装，跳过。"
            } elseif (Test-Cmd "npm") {
                Add-Log $txtLog "正在安装 Claude Code，请稍候..."
                $out = & npm install -g @anthropic-ai/claude-code 2>&1 | Select-Object -Last 5
                $out | ForEach-Object { Add-Log $txtLog $_ }
                Refresh-Path
                if (Test-Cmd "claude") { Add-Log $txtLog "Claude Code 安装成功。" }
                else { Add-Log $txtLog "[提示] 安装完成，需重启终端后使用 claude 命令。" }
            } else {
                Add-Log $txtLog "[错误] npm 不可用，无法安装 Claude Code。"
            }
        }

        # Codex CLI
        if ($installCodex) {
            Add-Log $txtLog "--- 安装 Codex CLI ---"
            if (Test-Cmd "codex") {
                Add-Log $txtLog "Codex CLI $(& codex --version 2>$null) 已安装，跳过。"
            } elseif (Test-Cmd "npm") {
                Add-Log $txtLog "正在安装 Codex CLI，请稍候..."
                $out = & npm install -g @openai/codex 2>&1 | Select-Object -Last 5
                $out | ForEach-Object { Add-Log $txtLog $_ }
                Refresh-Path
                if (Test-Cmd "codex") { Add-Log $txtLog "Codex CLI 安装成功。" }
                else { Add-Log $txtLog "[提示] 安装完成，需重启终端后使用 codex 命令。" }
            } else {
                Add-Log $txtLog "[错误] npm 不可用，无法安装 Codex CLI。"
            }

            # 询问是否安装桌面版
            $ans = [System.Windows.Forms.MessageBox]::Show(
                "是否打开 Codex 桌面版下载页面？",
                "Codex 桌面版",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
                Start-Process "https://openai.com/codex/"
                Add-Log $txtLog "已打开 Codex 桌面版下载页面。"
            }
        }

        Add-Log $txtLog "=== 安装步骤完成，请继续配置 API 令牌 ==="
    } catch {
        Add-Log $txtLog "[错误] $_"
    } finally {
        $btnInstall.Enabled = $true
    }
})

# ---------------------------------------------------------------------------
# 事件: 写入配置
# ---------------------------------------------------------------------------
$btnConfigure.Add_Click({
    $apiKey = $txtToken.Text.Trim()
    $model  = $txtModel.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入令牌。", "缺少令牌", "OK", "Warning") | Out-Null
        return
    }

    # 如果是仅配置 API 模式，默认配置 Claude Code
    if ($rbApiOnly.Checked) {
        $installClaude = $true
        $installCodex  = $false
    } else {
        $installClaude = $rbClaude.Checked -or $rbBoth.Checked
        $installCodex  = $rbCodex.Checked  -or $rbBoth.Checked
    }

    try {
        if ($installClaude) {
            Save-ClaudeConfig -ApiKey $apiKey -Model $model
            Add-Log $txtLog "Claude Code 配置已写入: $SETTINGS_PATH"
        }
        if ($installCodex) {
            Save-CodexConfig -ApiKey $apiKey -Model $model
            Add-Log $txtLog "Codex 配置已写入: $CODEX_HOME"
        }
        if ([string]::IsNullOrWhiteSpace($model)) {
            Add-Log $txtLog "模型: 使用服务默认"
        } else {
            Add-Log $txtLog "模型: $model"
        }
        [System.Windows.Forms.MessageBox]::Show("配置写入成功！", "完成", "OK", "Information") | Out-Null
    } catch {
        Add-Log $txtLog "[错误] 配置写入失败: $_"
    }
})

# ---------------------------------------------------------------------------
# 事件: 测试连接
# ---------------------------------------------------------------------------
$btnTest.Add_Click({
    $apiKey = $txtToken.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入令牌。", "缺少令牌", "OK", "Warning") | Out-Null
        return
    }

    $btnTest.Enabled = $false
    Add-Log $txtLog "正在测试 API 连接..."

    try {
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type"  = "application/json"
        }
        $response = Invoke-RestMethod -Uri "${DEFAULT_BASE_URL}/v1/models" -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction Stop
        Add-Log $txtLog "[成功] API 连接测试通过！"
        [System.Windows.Forms.MessageBox]::Show("API 连接测试成功！", "测试通过", "OK", "Information") | Out-Null
    } catch {
        Add-Log $txtLog "[失败] API 连接测试失败: $($_.Exception.Message)"
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "API 连接失败。`n`n可能原因:`n  1. 令牌错误或已过期`n  2. 网络连接问题`n  3. API 服务暂时不可用`n`n是否打开配置文件手动检查？",
            "连接失败",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            if (Test-Path $SETTINGS_PATH) {
                Start-Process notepad $SETTINGS_PATH
            } else {
                Add-Log $txtLog "[提示] 配置文件不存在，请先点击「写入配置」。"
            }
        }
    } finally {
        $btnTest.Enabled = $true
    }
})

# ---------------------------------------------------------------------------
# 启动
# ---------------------------------------------------------------------------
Add-Log $txtLog "界面已启动。请选择模式和工具，然后按步骤操作。"
if (-not $IS_ADMIN) {
    Add-Log $txtLog "[提示] 当前非管理员运行，安装环境需右键以管理员身份启动。配置 API 不受影响。"
}
Refresh-Path

# 检测当前状态
$status = @()
if (Test-Cmd "node") { $status += "Node.js $(& node --version 2>$null)" }
if (Test-Cmd "git")   { $status += "$(& git --version 2>$null)" }
if (Test-Cmd "claude") { $status += "Claude Code 已安装" }
if (Test-Cmd "codex")  { $status += "Codex CLI 已安装" }
if ($status.Count -gt 0) {
    Add-Log $txtLog "当前已安装: $($status -join ' | ')"
}
if (Test-Path $SETTINGS_PATH) {
    if (Select-String -Path $SETTINGS_PATH -Pattern "ANTHROPIC_AUTH_TOKEN" -Quiet) {
        Add-Log $txtLog "检测到已有 Claude Code API 配置。"
    }
}

[void]$form.ShowDialog()
