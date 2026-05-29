# ============================================================================
# Claude Code 图形启动器
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    $scriptPath = $PSCommandPath
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$TOKEN_URL = "https://2api.cloud/console/token"
$DEFAULT_BASE_URL = "https://2api.cloud/"
$CODEX_DEFAULT_BASE_URL = "https://2api.cloud/v1"
$CODEX_PROVIDER_NAME = "88code"
$SETTINGS_PATH = Join-Path $env:USERPROFILE ".claude\settings.json"
$CODEX_HOME = Join-Path $env:USERPROFILE ".codex"
$CODEX_CONFIG_PATH = Join-Path $CODEX_HOME "config.toml"
$CODEX_AUTH_PATH = Join-Path $CODEX_HOME "auth.json"
$MODELS = @("glm-5", "glm-4.7", "glm-4.5", "glm-4.7-flash", "glm-4-flash", "glm-4.5-air")

function Get-ClaudeSettings {
    if (Test-Path $SETTINGS_PATH) {
        try {
            return Get-Content -Path $SETTINGS_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            return [pscustomobject]@{}
        }
    }

    return [pscustomobject]@{}
}

function Ensure-EnvObject {
    param([Parameter(Mandatory = $true)]$Settings)

    if (-not $Settings.PSObject.Properties["env"] -or $null -eq $Settings.env) {
        $Settings | Add-Member -MemberType NoteProperty -Name "env" -Value ([pscustomobject]@{}) -Force
    }

    return $Settings.env
}

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowEmptyString()][string]$Value
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Remove-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.PSObject.Properties.Remove($Name)
    }
}

function Save-ApiConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [AllowEmptyString()][string]$OpusModel,
        [AllowEmptyString()][string]$SonnetModel,
        [AllowEmptyString()][string]$HaikuModel
    )

    $settings = Get-ClaudeSettings
    $envConfig = Ensure-EnvObject -Settings $settings

    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_BASE_URL" -Value $BaseUrl
    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_API_KEY" -Value $ApiKey
    Remove-ObjectProperty -Object $envConfig -Name "ANTHROPIC_AUTH_TOKEN"

    if ([string]::IsNullOrWhiteSpace($OpusModel)) {
        Remove-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_OPUS_MODEL"
    } else {
        Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_OPUS_MODEL" -Value $OpusModel
    }

    if ([string]::IsNullOrWhiteSpace($SonnetModel)) {
        Remove-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_SONNET_MODEL"
    } else {
        Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_SONNET_MODEL" -Value $SonnetModel
    }

    if ([string]::IsNullOrWhiteSpace($HaikuModel)) {
        Remove-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_HAIKU_MODEL"
    } else {
        Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_HAIKU_MODEL" -Value $HaikuModel
    }

    $configDir = Split-Path -Parent $SETTINGS_PATH
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $SETTINGS_PATH -Encoding UTF8 -Force
}

function Save-CodexConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [AllowEmptyString()][string]$Model
    )

    if (-not (Test-Path $CODEX_HOME)) {
        New-Item -ItemType Directory -Path $CODEX_HOME -Force | Out-Null
    }

    [ordered]@{
        OPENAI_API_KEY = $ApiKey
    } | ConvertTo-Json -Depth 5 | Out-File -FilePath $CODEX_AUTH_PATH -Encoding UTF8 -Force

    $existing = ""
    if (Test-Path $CODEX_CONFIG_PATH) {
        $existing = Get-Content -Path $CODEX_CONFIG_PATH -Raw -Encoding UTF8
    }

    $existing = [regex]::Replace($existing, '(?m)^model_provider\s*=.*\r?\n?', '')
    $existing = [regex]::Replace($existing, '(?m)^model\s*=.*\r?\n?', '')
    $existing = [regex]::Replace($existing, '(?ms)^\[model_providers\.88code\]\r?\n.*?(?=^\[|\z)', '')
    $existing = $existing.TrimStart()

    $top = "model_provider = `"$CODEX_PROVIDER_NAME`"`r`n"
    if (-not [string]::IsNullOrWhiteSpace($Model)) {
        $top += "model = `"$Model`"`r`n"
    }
    $top += "`r`n"

    $provider = @"
[model_providers.88code]
name = "88code"
base_url = "$BaseUrl"
wire_api = "responses"
env_key = "key88"
requires_openai_auth = true

"@

    ($top + $provider + $existing.TrimStart()) | Out-File -FilePath $CODEX_CONFIG_PATH -Encoding UTF8 -Force
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-InstallState {
    Refresh-Path

    $nodeOk = $false
    $nodeVersion = ""
    if (Test-CommandExists "node") {
        $nodeVersion = (& node --version 2>$null)
        try {
            $majorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
            $nodeOk = $majorVersion -ge 18
        }
        catch {
            $nodeOk = $false
        }
    }

    $npmOk = Test-CommandExists "npm"
    $gitOk = Test-CommandExists "git"
    $claudeOk = Test-CommandExists "claude"

    $missing = New-Object System.Collections.Generic.List[string]
    if (-not $nodeOk) { [void]$missing.Add("Node.js 18+") }
    if (-not $npmOk) { [void]$missing.Add("npm") }
    if (-not $gitOk) { [void]$missing.Add("Git") }
    if (-not $claudeOk) { [void]$missing.Add("Claude Code") }

    return [pscustomobject]@{
        NodeOk = $nodeOk
        NpmOk = $npmOk
        GitOk = $gitOk
        ClaudeOk = $claudeOk
        NodeVersion = $nodeVersion
        Missing = $missing.ToArray()
    }
}

function Add-Status {
    param([string]$Message)
    $time = Get-Date -Format "HH:mm:ss"
    $statusBox.AppendText("[$time] $Message`r`n")
}

function New-Label {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 120)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, 24)
    $label.TextAlign = "MiddleLeft"
    return $label
}

function New-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 140)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 34)
    return $button
}

function New-Combo {
    param([int]$X, [int]$Y, [int]$SelectedIndex = -1)
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = "DropDown"
    $combo.Location = New-Object System.Drawing.Point($X, $Y)
    $combo.Size = New-Object System.Drawing.Size(150, 26)
    [void]$combo.Items.AddRange($MODELS)
    if ($SelectedIndex -ge 0) {
        $combo.SelectedIndex = $SelectedIndex
    }
    return $combo
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude / Codex 安装与 API 配置助手"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 620)
$form.MinimumSize = New-Object System.Drawing.Size(760, 620)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Claude / Codex 安装与 API 配置助手"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.Size = New-Object System.Drawing.Size(520, 34)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "先选择 Claude Code 或 Codex，再安装和配置 API；模型可选，留空则使用服务默认模型。"
$subtitle.Location = New-Object System.Drawing.Point(26, 56)
$subtitle.Size = New-Object System.Drawing.Size(680, 24)
$form.Controls.Add($subtitle)

$toolGroup = New-Object System.Windows.Forms.GroupBox
$toolGroup.Text = "0. 选择工具"
$toolGroup.Location = New-Object System.Drawing.Point(24, 88)
$toolGroup.Size = New-Object System.Drawing.Size(700, 52)
$form.Controls.Add($toolGroup)

$claudeRadio = New-Object System.Windows.Forms.RadioButton
$claudeRadio.Text = "Claude Code"
$claudeRadio.Location = New-Object System.Drawing.Point(22, 22)
$claudeRadio.Size = New-Object System.Drawing.Size(130, 22)
$claudeRadio.Checked = $true
$toolGroup.Controls.Add($claudeRadio)

$codexRadio = New-Object System.Windows.Forms.RadioButton
$codexRadio.Text = "Codex 桌面端"
$codexRadio.Location = New-Object System.Drawing.Point(170, 22)
$codexRadio.Size = New-Object System.Drawing.Size(140, 22)
$toolGroup.Controls.Add($codexRadio)

$installGroup = New-Object System.Windows.Forms.GroupBox
$installGroup.Text = "1. 安装"
$installGroup.Location = New-Object System.Drawing.Point(24, 150)
$installGroup.Size = New-Object System.Drawing.Size(700, 86)
$form.Controls.Add($installGroup)

$installButton = New-Button "开始安装" 22 32 150
$installGroup.Controls.Add($installButton)

$installHint = New-Object System.Windows.Forms.Label
$installHint.Text = "先检测 Node.js、npm、Git、Claude Code；全部已有则跳过，只安装缺失项。"
$installHint.Location = New-Object System.Drawing.Point(190, 38)
$installHint.Size = New-Object System.Drawing.Size(470, 22)
$installGroup.Controls.Add($installHint)

$apiGroup = New-Object System.Windows.Forms.GroupBox
$apiGroup.Text = "2. 配置 API"
$apiGroup.Location = New-Object System.Drawing.Point(24, 248)
$apiGroup.Size = New-Object System.Drawing.Size(700, 210)
$form.Controls.Add($apiGroup)

$openTokenButton = New-Button "打开令牌页面" 22 32 150
$apiGroup.Controls.Add($openTokenButton)

$tokenLabel = New-Label "令牌" 22 82 80
$apiGroup.Controls.Add($tokenLabel)

$tokenBox = New-Object System.Windows.Forms.TextBox
$tokenBox.Location = New-Object System.Drawing.Point(110, 82)
$tokenBox.Size = New-Object System.Drawing.Size(420, 26)
$tokenBox.PasswordChar = "*"
$apiGroup.Controls.Add($tokenBox)

$showToken = New-Object System.Windows.Forms.CheckBox
$showToken.Text = "显示"
$showToken.Location = New-Object System.Drawing.Point(548, 82)
$showToken.Size = New-Object System.Drawing.Size(70, 24)
$apiGroup.Controls.Add($showToken)

$baseLabel = New-Label "接口地址" 22 120 80
$apiGroup.Controls.Add($baseLabel)

$baseUrlBox = New-Object System.Windows.Forms.TextBox
$baseUrlBox.Location = New-Object System.Drawing.Point(110, 120)
$baseUrlBox.Size = New-Object System.Drawing.Size(420, 26)
$baseUrlBox.Text = $DEFAULT_BASE_URL
$apiGroup.Controls.Add($baseUrlBox)

$opusLabel = New-Label "Opus 可选" 22 158 70
$sonnetLabel = New-Label "Sonnet 可选" 245 158 80
$haikuLabel = New-Label "Haiku 可选" 475 158 75
$apiGroup.Controls.Add($opusLabel)
$apiGroup.Controls.Add($sonnetLabel)
$apiGroup.Controls.Add($haikuLabel)

$opusCombo = New-Combo 92 158
$sonnetCombo = New-Combo 335 158
$haikuCombo = New-Combo 550 158
$apiGroup.Controls.Add($opusCombo)
$apiGroup.Controls.Add($sonnetCombo)
$apiGroup.Controls.Add($haikuCombo)

$configureButton = New-Button "一键配置" 548 116 120
$apiGroup.Controls.Add($configureButton)

$testButton = New-Button "测试连接" 548 32 120
$apiGroup.Controls.Add($testButton)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "状态"
$statusGroup.Location = New-Object System.Drawing.Point(24, 470)
$statusGroup.Size = New-Object System.Drawing.Size(700, 98)
$form.Controls.Add($statusGroup)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(14, 24)
$statusBox.Size = New-Object System.Drawing.Size(672, 62)
$statusBox.Multiline = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.ReadOnly = $true
$statusGroup.Controls.Add($statusBox)

function Get-SelectedMode {
    if ($codexRadio.Checked) {
        return "Codex"
    }
    return "Claude"
}

function Update-ModeUi {
    if ((Get-SelectedMode) -eq "Codex") {
        $installHint.Text = "先检测 Codex CLI；已安装则跳过，未安装则通过 npm 安装。"
        $baseUrlBox.Text = $CODEX_DEFAULT_BASE_URL
        $opusLabel.Text = "模型可选"
        $sonnetLabel.Text = "备用可选"
        $haikuLabel.Text = "备用可选"
        $testButton.Text = "测试 Codex"
        $configureButton.Text = "配置 Codex"
    }
    else {
        $installHint.Text = "先检测 Node.js、npm、Git、Claude Code；全部已有则跳过，只安装缺失项。"
        $baseUrlBox.Text = $DEFAULT_BASE_URL
        $opusLabel.Text = "Opus 可选"
        $sonnetLabel.Text = "Sonnet 可选"
        $haikuLabel.Text = "Haiku 可选"
        $testButton.Text = "测试连接"
        $configureButton.Text = "一键配置"
    }
}

$showToken.Add_CheckedChanged({
    if ($showToken.Checked) {
        $tokenBox.PasswordChar = [char]0
    }
    else {
        $tokenBox.PasswordChar = "*"
    }
})

$claudeRadio.Add_CheckedChanged({ Update-ModeUi })
$codexRadio.Add_CheckedChanged({ Update-ModeUi })

$openTokenButton.Add_Click({
    Start-Process $TOKEN_URL
    Add-Status "已打开令牌页面：$TOKEN_URL"
})

$installButton.Add_Click({
    $installButton.Enabled = $false

    try {
        if ((Get-SelectedMode) -eq "Codex") {
            Add-Status "正在检测 Codex CLI..."
            if (Test-CommandExists "codex") {
                $codexVersion = (& codex --version 2>$null)
                Add-Status "检测到 Codex 已安装：$codexVersion，已跳过安装。"
                [System.Windows.Forms.MessageBox]::Show("Codex 已安装，无需重复安装。", "已跳过安装", "OK", "Information") | Out-Null
                return
            }

            if (-not (Test-CommandExists "npm")) {
                Add-Status "未检测到 npm，请先安装 Node.js，或切换到 Claude Code 模式点击开始安装。"
                return
            }

            Add-Status "未检测到 Codex，开始通过 npm 安装 @openai/codex..."
            $process = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"npm install -g @openai/codex`"" -Wait -PassThru
            if ($process.ExitCode -eq 0) {
                Add-Status "Codex 安装完成。"
            }
            else {
                Add-Status "Codex 安装结束，退出代码：$($process.ExitCode)。"
            }
            return
        }

        Add-Status "正在检测本机安装状态..."
        $state = Get-InstallState

        if ($state.Missing.Count -eq 0) {
            Add-Status "检测到 Node.js、npm、Git、Claude Code 均已安装，已跳过安装。"
            [System.Windows.Forms.MessageBox]::Show("检测到所需组件都已安装，无需重复安装。", "已跳过安装", "OK", "Information") | Out-Null
            return
        }

        Add-Status "缺少组件：$($state.Missing -join '、')。将只安装缺失或不满足要求的组件。"
        Add-Status "开始安装，请等待安装窗口完成..."
        $installPath = Join-Path $PSScriptRoot "install.ps1"
        $process = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installPath`" -SkipApiConfig -NonInteractive" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Add-Status "安装流程已完成。现在可以打开令牌页面并配置 API。"
        }
        else {
            Add-Status "安装流程结束，退出代码：$($process.ExitCode)。请查看安装窗口或日志。"
        }
    }
    catch {
        Add-Status "安装启动失败：$($_.Exception.Message)"
    }
    finally {
        $installButton.Enabled = $true
    }
})

$configureButton.Add_Click({
    $apiKey = $tokenBox.Text.Trim()
    $baseUrl = $baseUrlBox.Text.Trim().TrimEnd("/")

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入令牌。", "缺少令牌", "OK", "Warning") | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        [System.Windows.Forms.MessageBox]::Show("请填写 API 接口地址。", "缺少接口地址", "OK", "Warning") | Out-Null
        return
    }

    try {
        if ((Get-SelectedMode) -eq "Codex") {
            Save-CodexConfig -ApiKey $apiKey -BaseUrl $baseUrl -Model $opusCombo.Text.Trim()
            Add-Status "Codex 配置成功，已写入：$CODEX_CONFIG_PATH 和 $CODEX_AUTH_PATH"
            [System.Windows.Forms.MessageBox]::Show("Codex 配置成功。请重启 Codex 桌面端或打开新的终端运行 codex。", "配置完成", "OK", "Information") | Out-Null
            return
        }

        Save-ApiConfig -ApiKey $apiKey -BaseUrl $baseUrl -OpusModel $opusCombo.Text.Trim() -SonnetModel $sonnetCombo.Text.Trim() -HaikuModel $haikuCombo.Text.Trim()
        Add-Status "API 配置成功，已写入：$SETTINGS_PATH"
        [System.Windows.Forms.MessageBox]::Show("API 配置成功。请打开新的终端运行 claude。", "配置完成", "OK", "Information") | Out-Null
    }
    catch {
        Add-Status "配置失败：$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("配置失败：$($_.Exception.Message)", "错误", "OK", "Error") | Out-Null
    }
})

$testButton.Add_Click({
    $apiKey = $tokenBox.Text.Trim()
    $baseUrl = $baseUrlBox.Text.Trim().TrimEnd("/")

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入令牌。", "缺少令牌", "OK", "Warning") | Out-Null
        return
    }

    try {
        if ((Get-SelectedMode) -eq "Codex") {
            if (-not (Test-CommandExists "codex")) {
                Add-Status "测试失败：未检测到 codex 命令，请先安装 Codex。"
                return
            }

            Save-CodexConfig -ApiKey $apiKey -BaseUrl $baseUrl -Model $opusCombo.Text.Trim()
            Add-Status "正在通过 Codex CLI 测试连接..."

            $codexCmd = $null
            $candidates = Get-Command codex -All -ErrorAction SilentlyContinue
            foreach ($c in $candidates) {
                if ($c.Source -match '\.(cmd|bat|exe)$') { $codexCmd = $c.Source; break }
            }
            if (-not $codexCmd -and $candidates) {
                $candidate = $candidates | Select-Object -First 1
                $maybeCmd = "$($candidate.Source).cmd"
                if (Test-Path $maybeCmd) { $codexCmd = $maybeCmd }
                else { $codexCmd = $candidate.Source }
            }
            if (-not $codexCmd) {
                Add-Status "测试失败：未能解析 codex 可执行文件路径。"
                return
            }
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            if ($codexCmd -match '\.(cmd|bat)$') {
                $psi.FileName = "$env:ComSpec"
                if ([string]::IsNullOrWhiteSpace($opusCombo.Text)) {
                    $psi.Arguments = "/c `"`"$codexCmd`" exec `"请只回复：连接成功`"`""
                } else {
                    $psi.Arguments = "/c `"`"$codexCmd`" exec `"请只回复：连接成功`" --model `"$($opusCombo.Text.Trim())`"`""
                }
            } else {
                $psi.FileName = $codexCmd
                if ([string]::IsNullOrWhiteSpace($opusCombo.Text)) {
                    $psi.Arguments = 'exec "请只回复：连接成功"'
                } else {
                    $psi.Arguments = "exec `"请只回复：连接成功`" --model `"$($opusCombo.Text.Trim())`""
                }
            }
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
            $psi.EnvironmentVariables["OPENAI_API_KEY"] = $apiKey

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            [void]$process.Start()

            if (-not $process.WaitForExit(120000)) {
                $process.Kill()
                Add-Status "测试超时：Codex CLI 120 秒内没有返回。"
                return
            }

            $stdout = $process.StandardOutput.ReadToEnd().Trim()
            $stderr = $process.StandardError.ReadToEnd().Trim()

            if ($process.ExitCode -eq 0) {
                Add-Status "Codex 测试成功：$stdout"
            }
            else {
                $message = if ($stderr) { $stderr } else { $stdout }
                Add-Status "Codex 测试失败：$message"
            }
            return
        }

        if (-not (Test-CommandExists "claude")) {
            Add-Status "测试失败：未检测到 claude 命令，请先安装 Claude Code。"
            return
        }

        $testModel = $sonnetCombo.Text.Trim()

        Save-ApiConfig -ApiKey $apiKey -BaseUrl $baseUrl -OpusModel $opusCombo.Text.Trim() -SonnetModel $testModel -HaikuModel $haikuCombo.Text.Trim()

        Add-Status "正在通过 Claude Code 测试连接..."

        $claudeCmd = $null
        $claudeCandidates = Get-Command claude -All -ErrorAction SilentlyContinue
        foreach ($c in $claudeCandidates) {
            if ($c.Source -match '\.(cmd|bat|exe)$') { $claudeCmd = $c.Source; break }
        }
        if (-not $claudeCmd -and $claudeCandidates) {
            $candidate = $claudeCandidates | Select-Object -First 1
            $maybeCmd = "$($candidate.Source).cmd"
            if (Test-Path $maybeCmd) { $claudeCmd = $maybeCmd }
            else { $claudeCmd = $candidate.Source }
        }
        if (-not $claudeCmd) {
            Add-Status "测试失败：未能解析 claude 可执行文件路径。"
            return
        }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($claudeCmd -match '\.(cmd|bat)$') {
            $psi.FileName = "$env:ComSpec"
            if ([string]::IsNullOrWhiteSpace($testModel)) {
                $psi.Arguments = "/c `"`"$claudeCmd`" -p `"请只回复：连接成功`" --output-format text`""
            } else {
                $psi.Arguments = "/c `"`"$claudeCmd`" -p `"请只回复：连接成功`" --output-format text --model `"$testModel`"`""
            }
        } else {
            $psi.FileName = $claudeCmd
            if ([string]::IsNullOrWhiteSpace($testModel)) {
                $psi.Arguments = '-p "请只回复：连接成功" --output-format text'
            } else {
                $psi.Arguments = "-p `"请只回复：连接成功`" --output-format text --model `"$testModel`""
            }
        }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $psi.EnvironmentVariables["ANTHROPIC_BASE_URL"] = $baseUrl
        $psi.EnvironmentVariables["ANTHROPIC_API_KEY"] = $apiKey
        if ($psi.EnvironmentVariables.ContainsKey("ANTHROPIC_AUTH_TOKEN")) {
            $psi.EnvironmentVariables.Remove("ANTHROPIC_AUTH_TOKEN")
        }
        foreach ($key in @("ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL")) {
            if ($psi.EnvironmentVariables.ContainsKey($key)) {
                $psi.EnvironmentVariables.Remove($key)
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($opusCombo.Text)) {
            $psi.EnvironmentVariables["ANTHROPIC_DEFAULT_OPUS_MODEL"] = $opusCombo.Text.Trim()
        }
        if (-not [string]::IsNullOrWhiteSpace($testModel)) {
            $psi.EnvironmentVariables["ANTHROPIC_DEFAULT_SONNET_MODEL"] = $testModel
        }
        if (-not [string]::IsNullOrWhiteSpace($haikuCombo.Text)) {
            $psi.EnvironmentVariables["ANTHROPIC_DEFAULT_HAIKU_MODEL"] = $haikuCombo.Text.Trim()
        }

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        if (-not $process.WaitForExit(90000)) {
            $process.Kill()
            Add-Status "测试超时：Claude Code 90 秒内没有返回。"
            return
        }

        $stdout = $process.StandardOutput.ReadToEnd().Trim()
        $stderr = $process.StandardError.ReadToEnd().Trim()

        if ($process.ExitCode -eq 0) {
            Add-Status "测试成功：$stdout"
        }
        else {
            $message = if ($stderr) { $stderr } else { $stdout }
            Add-Status "测试失败：$message"
        }
    }
    catch {
        Add-Status "测试失败：$($_.Exception.Message)"
    }
})

Update-ModeUi
Add-Status "界面已启动。请先选择 Claude Code 或 Codex。"
[void]$form.ShowDialog()


















