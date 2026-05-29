# Claude / Codex 一键安装配置助手

这是一个给 Windows 新手使用的图形化安装配置工具。双击启动后，可以选择安装和配置：

- Claude Code
- Codex 桌面端 / Codex CLI

工具会帮你完成安装检测、打开令牌页面、写入配置文件和连接测试。

## 适合谁用

- 不熟悉命令行，但想使用 Claude Code 或 Codex 的用户
- 已经有 2api 令牌，希望一键写入配置的用户
- 想把工具上传到 GitHub，让别人下载后照着操作的用户

## 从 GitHub 下载

1. 打开本项目的 GitHub 页面。
2. 点击绿色的 `Code` 按钮。
3. 点击 `Download ZIP`。
4. 下载完成后右键解压，不要只单独下载某一个文件。
5. 解压后进入文件夹，双击 `start.bat`。

## 下载后怎么用

1. 确认所有文件都在同一个文件夹里。
2. 双击 `start.bat`。
3. 如果 Windows 弹出管理员权限提示，点“是”。
4. 在界面顶部选择 `Claude Code` 或 `Codex 桌面端`。
5. 点击 `开始安装`。
6. 点击 `打开令牌页面`，获取你的 2api 令牌。
7. 回到界面，把令牌粘贴进去。
8. 模型可以留空，留空会使用服务默认模型。
9. 点击 `一键配置` 或 `配置 Codex`。
10. 点击 `测试连接`。

看到“连接成功”后，就可以开始使用。

## 接口地址

工具已经内置默认地址：

| 工具 | 默认接口地址 |
|------|--------------|
| Claude Code | `https://2api.cloud/` |
| Codex | `https://2api.cloud/v1` |

一般不需要修改。如果你的服务商给了别的接口地址，再在界面里手动改。

## 启动 Claude Code

配置成功后，打开新的 PowerShell 或 CMD，运行：

```powershell
claude
```

也可以测试一句：

```powershell
claude -p "请只回复：连接成功" --output-format text
```

## 启动 Codex

配置成功后，打开新的 PowerShell 或 CMD，运行：

```powershell
codex
```

也可以测试一句：

```powershell
codex exec "请只回复：连接成功"
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `start.bat` | 图形界面入口，普通用户双击这个文件 |
| `ClaudeCodeGUI.ps1` | 图形界面主脚本 |
| `一键安装.bat` | 旧版 Claude Code 命令行安装入口 |
| `配置API.bat` | 旧版 Claude Code 命令行配置入口 |
| `install.ps1` | Claude Code 安装脚本 |
| `configure-api.ps1` | Claude Code 命令行配置脚本 |
| `ClaudeCodeInstaller.iss` | Inno Setup 打包脚本 |
| `generate_guide.py` | 生成 Word/PDF 说明书 |
| `requirements.txt` | 生成说明书需要的 Python 依赖 |
| `Claude Code 使用说明.docx` | Word 说明书 |
| `Claude Code 使用说明.pdf` | PDF 说明书 |

## 上传 GitHub 前注意

不要上传你的个人密钥和本机配置：

- 不要上传 `%USERPROFILE%\.claude\settings.json`
- 不要上传 `%USERPROFILE%\.codex\auth.json`
- 不要把自己的 2api 令牌写进 README、脚本或截图

本项目目录里的脚本不会保存你的令牌；令牌只会写到当前用户目录下的 Claude/Codex 配置文件。

## 常见问题

### 双击没有反应

右键 `start.bat`，选择“以管理员身份运行”。

### 提示 PowerShell 禁止运行脚本

本工具的 bat 会自动使用：

```powershell
-ExecutionPolicy Bypass
```

如果仍然失败，请右键以管理员身份运行。

### Claude Code 报 Auth conflict

这是同时设置了 `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_API_KEY`。新版工具只写 `ANTHROPIC_API_KEY`。

如果你之前手动配置过，可以删除：

```json
"ANTHROPIC_AUTH_TOKEN"
```

或者重新用本工具点一次“一键配置”。

### 测试提示模型不可用

说明你的 2api 市场没有订阅该模型。把模型框留空，使用默认模型，或者填写你已经订阅的模型名。

### 测试提示余额不足

说明接口已经通了，但账号余额不足。去 2api 检查余额或套餐。

### Codex 接口地址为什么带 `/v1`

Codex 使用 OpenAI 风格接口，所以默认是：

```text
https://2api.cloud/v1
```

Claude Code 使用 Anthropic 风格接口，所以默认是：

```text
https://2api.cloud/
```

## 重新生成说明书

如果修改了 `generate_guide.py`，可以重新生成 Word/PDF：

```powershell
pip install -r requirements.txt
python generate_guide.py
```

如果本机 Python 缺依赖，先安装 `requirements.txt` 里的依赖。

## 打包成 exe 安装包

1. 安装 Inno Setup。
2. 打开 `ClaudeCodeInstaller.iss`。
3. 点击 `Build -> Compile`。
4. 生成的安装包在 `Output` 目录。

## 免责声明

本工具只负责安装和写入本机配置。Claude Code、Codex、2api 账号、模型订阅和费用由对应服务方负责。请妥善保管自己的令牌。

