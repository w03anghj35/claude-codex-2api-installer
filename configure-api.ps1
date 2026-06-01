# ============================================================================
# Claude Code API 配置工具 - 智谱 GLM / Anthropic 兼容 API
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$TOKEN_URL = "https://2api.cloud/console/token"
$DEFAULT_BASE_URL = "https://2api.cloud/"
$SETTINGS_PATH = Join-Path $env:USERPROFILE ".claude\settings.json"

$GLM_MODELS = @(
    @{ Name = "glm-5";         Desc = "旗舰模型 745B MoE，最强（对标 Claude Opus）" }
    @{ Name = "glm-4.7";       Desc = "编程增强 SWE-bench 73.8（对标 Claude Sonnet）" }
    @{ Name = "glm-4.5";       Desc = "Agent 基座，工具调用优化" }
    @{ Name = "glm-4.7-flash"; Desc = "30B MoE 轻量快速（对标 Claude Haiku）" }
    @{ Name = "glm-4-flash";   Desc = "免费模型，轻量任务" }
    @{ Name = "glm-4.5-air";   Desc = "轻量快速，低成本" }
)

function Get-ClaudeSettings {
    if (Test-Path $SETTINGS_PATH) {
        try {
            return Get-Content -Path $SETTINGS_PATH -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            Write-Host "  [警告] 配置文件格式异常，将创建新的配置。" -ForegroundColor Yellow
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

function Save-ClaudeSettings {
    param([Parameter(Mandatory = $true)]$Settings)

    $configDir = Split-Path -Parent $SETTINGS_PATH
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $Settings | ConvertTo-Json -Depth 10 | Out-File -FilePath $SETTINGS_PATH -Encoding utf8NoBOM -Force
}

function Mask-Secret {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "(未设置)"
    }

    $prefixLength = [Math]::Min(8, $Value.Length)
    return $Value.Substring(0, $prefixLength) + "****"
}

function Show-CurrentConfig {
    Write-Host ""
    Write-Host "  当前 API 配置:" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------" -ForegroundColor Gray

    if (-not (Test-Path $SETTINGS_PATH)) {
        Write-Host "    (尚未配置)" -ForegroundColor DarkGray
        Write-Host "  ----------------------------------------" -ForegroundColor Gray
        Write-Host ""
        return
    }

    try {
        $settings = Get-ClaudeSettings
        $envConfig = $settings.env

        Write-Host "    ANTHROPIC_BASE_URL             = $($envConfig.ANTHROPIC_BASE_URL)" -ForegroundColor White
        Write-Host "    ANTHROPIC_API_KEY              = $(Mask-Secret $envConfig.ANTHROPIC_API_KEY)" -ForegroundColor White
        Write-Host "    ANTHROPIC_DEFAULT_OPUS_MODEL   = $($envConfig.ANTHROPIC_DEFAULT_OPUS_MODEL)" -ForegroundColor White
        Write-Host "    ANTHROPIC_DEFAULT_SONNET_MODEL = $($envConfig.ANTHROPIC_DEFAULT_SONNET_MODEL)" -ForegroundColor White
        Write-Host "    ANTHROPIC_DEFAULT_HAIKU_MODEL  = $($envConfig.ANTHROPIC_DEFAULT_HAIKU_MODEL)" -ForegroundColor White
    }
    catch {
        Write-Host "    (配置文件格式异常)" -ForegroundColor DarkGray
    }

    Write-Host "  ----------------------------------------" -ForegroundColor Gray
    Write-Host ""
}

function Set-ApiConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter(Mandatory = $true)][string]$OpusModel,
        [Parameter(Mandatory = $true)][string]$SonnetModel,
        [Parameter(Mandatory = $true)][string]$HaikuModel,
        [string]$BaseUrl = $DEFAULT_BASE_URL
    )

    $settings = Get-ClaudeSettings
    $envConfig = Ensure-EnvObject -Settings $settings

    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_BASE_URL" -Value $BaseUrl
    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_API_KEY" -Value $ApiKey
    Remove-ObjectProperty -Object $envConfig -Name "ANTHROPIC_AUTH_TOKEN"
    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_HAIKU_MODEL" -Value $HaikuModel
    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_SONNET_MODEL" -Value $SonnetModel
    Set-ObjectProperty -Object $envConfig -Name "ANTHROPIC_DEFAULT_OPUS_MODEL" -Value $OpusModel

    Save-ClaudeSettings -Settings $settings
}

function Clear-ApiConfig {
    if (-not (Test-Path $SETTINGS_PATH)) {
        Write-Host "  [信息] 无配置文件，无需清除。" -ForegroundColor Gray
        return
    }

    $settings = Get-ClaudeSettings
    $envConfig = Ensure-EnvObject -Settings $settings

    $keys = @(
        "ANTHROPIC_BASE_URL",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_AUTH_TOKEN",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL"
    )

    foreach ($key in $keys) {
        Remove-ObjectProperty -Object $envConfig -Name $key
    }

    Save-ClaudeSettings -Settings $settings
    Write-Host "  [信息] Claude Code API 配置已清除。" -ForegroundColor Green
}

function Select-Model {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][int]$DefaultIndex
    )

    Write-Host ""
    Write-Host "  $Title" -ForegroundColor White

    for ($i = 0; $i -lt $GLM_MODELS.Count; $i++) {
        $tag = if ($i -eq $DefaultIndex) { "  <- 推荐" } else { "" }
        Write-Host "    [$($i + 1)] $($GLM_MODELS[$i].Name) - $($GLM_MODELS[$i].Desc)$tag" -ForegroundColor White
    }

    $choice = Read-Host "  请选择 (默认 $($DefaultIndex + 1))"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $GLM_MODELS[$DefaultIndex].Name
    }

    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx)) {
        return $GLM_MODELS[$DefaultIndex].Name
    }

    $idx = $idx - 1
    if ($idx -lt 0 -or $idx -ge $GLM_MODELS.Count) {
        return $GLM_MODELS[$DefaultIndex].Name
    }

    return $GLM_MODELS[$idx].Name
}

function Test-ApiConnection {
    Write-Host ""
    Write-Host "  正在测试 API 连接..." -ForegroundColor Cyan

    if (-not (Test-Path $SETTINGS_PATH)) {
        Write-Host "  [错误] 未找到配置文件，请先配置令牌。" -ForegroundColor Red
        return
    }

    try {
        $settings = Get-ClaudeSettings
        $envConfig = $settings.env
        $baseUrl = $envConfig.ANTHROPIC_BASE_URL
        $apiKey = $envConfig.ANTHROPIC_API_KEY
        $model = $envConfig.ANTHROPIC_DEFAULT_SONNET_MODEL

        if ([string]::IsNullOrWhiteSpace($baseUrl)) { $baseUrl = $DEFAULT_BASE_URL }
        if ([string]::IsNullOrWhiteSpace($model)) { $model = "glm-4.7" }

        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "  [错误] 配置文件中未找到令牌。" -ForegroundColor Red
            return
        }

        $testUrl = ($baseUrl.TrimEnd('/')) + "/v1/messages"
        $body = @{
            model = $model
            max_tokens = 20
            messages = @(
                @{
                    role = "user"
                    content = "请回复：连接成功"
                }
            )
        } | ConvertTo-Json -Depth 5

        Write-Host "  请求地址: $testUrl" -ForegroundColor Gray
        Write-Host "  使用模型: $model" -ForegroundColor Gray

        $commonHeaders = @{
            "Content-Type" = "application/json"
            "anthropic-version" = "2023-06-01"
            "User-Agent" = "ClaudeCodeInstaller/1.0"
        }

        $attempts = @(
            @{ Name = "Authorization Bearer"; Headers = $commonHeaders + @{ "Authorization" = "Bearer $apiKey" } },
            @{ Name = "x-api-key"; Headers = $commonHeaders + @{ "x-api-key" = $apiKey } },
            @{ Name = "双鉴权"; Headers = $commonHeaders + @{ "Authorization" = "Bearer $apiKey"; "x-api-key" = $apiKey } }
        )

        foreach ($attempt in $attempts) {
            try {
                Write-Host "  尝试鉴权方式: $($attempt.Name)" -ForegroundColor Gray
                $response = Invoke-RestMethod -Uri $testUrl -Method POST -Headers $attempt.Headers -Body $body -TimeoutSec 30

                if ($response.content -and $response.content.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  [成功] API 连接正常!" -ForegroundColor Green
                    Write-Host "  模型回复: $($response.content[0].text)" -ForegroundColor Green
                    return
                }

                Write-Host "  [警告] API 返回了意外的响应格式。" -ForegroundColor Yellow
                Write-Host "  响应: $($response | ConvertTo-Json -Depth 5)" -ForegroundColor Gray
                return
            }
            catch {
                Write-Host "  $($attempt.Name) 失败: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        Write-Host "  [错误] 所有鉴权方式均未通过。" -ForegroundColor Red
    }
    catch {
        Write-Host ""
        Write-Host "  [错误] API 连接失败。" -ForegroundColor Red
        Write-Host "  错误信息: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  请检查令牌、账户余额、网络连接，以及服务商是否支持 Anthropic Messages API。" -ForegroundColor Yellow
    }
}

while ($true) {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Magenta
    Write-Host "       Claude Code API 配置工具 - 智谱 GLM" -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor Magenta

    Show-CurrentConfig

    Write-Host "  请选择操作:" -ForegroundColor White
    Write-Host "    [1] 配置智谱 GLM 令牌" -ForegroundColor White
    Write-Host "    [2] 清除 API 配置" -ForegroundColor White
    Write-Host "    [3] 测试当前 API 连接" -ForegroundColor White
    Write-Host "    [4] 配置自定义 Anthropic 兼容 API" -ForegroundColor White
    Write-Host "    [Q] 退出" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "  请输入选项"

    if ($choice -eq "Q" -or $choice -eq "q") {
        Write-Host ""
        Write-Host "  配置工具已退出。请打开新的终端窗口使配置生效。" -ForegroundColor Yellow
        Write-Host ""
        break
    }

    if ($choice -eq "1") {
        Write-Host ""
        Write-Host "  获取令牌: $TOKEN_URL" -ForegroundColor Gray
        $openBrowser = Read-Host "  是否打开浏览器获取令牌? (Y/n)"
        if ($openBrowser -ne "n" -and $openBrowser -ne "N") {
            Start-Process $TOKEN_URL
        }

        $apiKey = Read-Host "  请输入令牌"
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "  [警告] 未输入令牌，操作取消。" -ForegroundColor Yellow
            Read-Host "  按 Enter 返回主菜单"
            continue
        }

        Write-Host ""
        Write-Host "  选择模型 (留空使用服务默认):" -ForegroundColor White
        Write-Host "    [0] 不指定模型，使用服务默认  <- 推荐" -ForegroundColor White
        for ($i = 0; $i -lt $GLM_MODELS.Count; $i++) {
            Write-Host "    [$($i + 1)] $($GLM_MODELS[$i].Name) - $($GLM_MODELS[$i].Desc)" -ForegroundColor White
        }
        $modelChoice = Read-Host "  请选择 (默认 0)"
        if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "0" }

        if ($modelChoice -eq "0") {
            Set-ApiConfig -ApiKey $apiKey -OpusModel "" -SonnetModel "" -HaikuModel ""
            Write-Host ""
            Write-Host "  [成功] 配置完成!" -ForegroundColor Green
            Write-Host "  模型: 使用服务默认" -ForegroundColor Green
        } else {
            $idx = [int]$modelChoice - 1
            if ($idx -ge 0 -and $idx -lt $GLM_MODELS.Count) {
                $selected = $GLM_MODELS[$idx].Name
                Set-ApiConfig -ApiKey $apiKey -OpusModel $selected -SonnetModel $selected -HaikuModel $selected
                Write-Host ""
                Write-Host "  [成功] 配置完成!" -ForegroundColor Green
                Write-Host "  模型: $selected" -ForegroundColor Green
            } else {
                Set-ApiConfig -ApiKey $apiKey -OpusModel "" -SonnetModel "" -HaikuModel ""
                Write-Host ""
                Write-Host "  [成功] 配置完成!" -ForegroundColor Green
                Write-Host "  模型: 使用服务默认" -ForegroundColor Green
            }
        }
        Write-Host "  配置已写入: $SETTINGS_PATH" -ForegroundColor Gray
        Read-Host "  按 Enter 返回主菜单"
    }
    elseif ($choice -eq "2") {
        $confirmClear = Read-Host "  确定要清除 API 配置吗? (y/N)"
        if ($confirmClear -eq "y" -or $confirmClear -eq "Y") {
            Clear-ApiConfig
        }
        Read-Host "  按 Enter 返回主菜单"
    }
    elseif ($choice -eq "3") {
        Test-ApiConnection
        Write-Host ""
        Read-Host "  按 Enter 返回主菜单"
    }
    elseif ($choice -eq "4") {
        Write-Host ""
        Write-Host "  配置自定义 Anthropic 兼容 API" -ForegroundColor Cyan
        Write-Host "  适用于其他中转服务商或自建网关，前提是它提供 /v1/messages 格式。" -ForegroundColor Gray
        Write-Host "  只支持 OpenAI 格式 (/v1/chat/completions) 的服务商不能直接使用。" -ForegroundColor Yellow
        Write-Host ""

        $baseUrl = Read-Host "  请输入 API Base URL (例如 https://your-provider.com/anthropic)"
        if ([string]::IsNullOrWhiteSpace($baseUrl)) {
            Write-Host "  [警告] 未输入 Base URL，操作取消。" -ForegroundColor Yellow
            Read-Host "  按 Enter 返回主菜单"
            continue
        }
        $baseUrl = $baseUrl.Trim().TrimEnd("/")

        $apiKey = Read-Host "  请输入令牌"
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "  [警告] 未输入令牌，操作取消。" -ForegroundColor Yellow
            Read-Host "  按 Enter 返回主菜单"
            continue
        }

        Write-Host ""
        Write-Host "  请填写模型名（全部留空则使用服务默认模型）。" -ForegroundColor White
        Write-Host "  Opus = 主力/复杂任务，Sonnet = 日常，Haiku = 轻量/快速。" -ForegroundColor Gray

        $opusModel = Read-Host "  Opus 模型名（主力，留空使用默认）"

        $sonnetModel = Read-Host "  Sonnet 模型名（日常，留空则使用 Opus 模型）"
        if ([string]::IsNullOrWhiteSpace($sonnetModel)) { $sonnetModel = $opusModel }

        $haikuModel = Read-Host "  Haiku 模型名（轻量，留空则使用 Sonnet 模型）"
        if ([string]::IsNullOrWhiteSpace($haikuModel)) { $haikuModel = $sonnetModel }

        Set-ApiConfig -ApiKey $apiKey -OpusModel $opusModel -SonnetModel $sonnetModel -HaikuModel $haikuModel -BaseUrl $baseUrl

        Write-Host ""
        Write-Host "  [成功] 自定义 API 配置完成!" -ForegroundColor Green
        Write-Host "  Base URL:    $baseUrl" -ForegroundColor Green
        Write-Host "  Opus 模型:   $opusModel" -ForegroundColor Green
        Write-Host "  Sonnet 模型: $sonnetModel" -ForegroundColor Green
        Write-Host "  Haiku 模型:  $haikuModel" -ForegroundColor Green
        Write-Host "  配置已写入: $SETTINGS_PATH" -ForegroundColor Gray
        Read-Host "  按 Enter 返回主菜单"
    }
    else {
        Write-Host "  无效选项，请重试。" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
}






