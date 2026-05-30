# Claude / Codex 一键安装配置助手

跨平台安装配置工具，支持 **Windows**、**macOS** 和 **Linux**。帮你一键完成安装和配置：

- Claude Code
- Codex 桌面端 / Codex CLI

工具会帮你完成安装检测、打开令牌页面、写入配置文件和连接测试。

## 快速开始

复制一行命令到终端，回车即可。

### macOS / Linux

```bash
# GitHub (海外网络)
curl -fsSL https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh | bash

# Gitee 国内镜像 (推荐国内用户)
curl -fsSL https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/setup.sh | bash

# GitHub 加速 (如果上面两个都不行)
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh | bash
```

### Windows

以管理员身份打开 **PowerShell**（不是 CMD），粘贴命令：

```powershell
# GitHub (海外网络)
irm https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.ps1 | iex

# Gitee 国内镜像 (推荐国内用户)
irm https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/setup.ps1 | iex

# GitHub 加速 (如果上面两个都不行)
irm https://ghfast.top/https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.ps1 | iex
```

如果你只有 CMD（命令提示符），用这个：

```cmd
powershell -ExecutionPolicy Bypass -Command "irm https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/setup.ps1 | iex"
```

> 三选一，哪个能用就用哪个。脚本会自动安装 Node.js、Git、Claude Code，并引导你配置 API 令牌。
>
> Windows 如果提示脚本执行策略问题，先运行：`Set-ExecutionPolicy Bypass -Scope Process`

## 适合谁用

- 不熟悉命令行，但想使用 Claude Code 或 Codex 的用户
- 已经有 2api 令牌，希望一键写入配置的用户
- 想把工具上传到 GitHub，让别人下载后照着操作的用户

## 从 GitHub / Gitee 下载

**GitHub：**

1. 打开本项目的 [GitHub 页面](https://github.com/w03anghj35/claude-codex-2api-installer)。
2. 点击绿色的 `Code` 按钮 → `Download ZIP`。

**Gitee（国内推荐）：**

1. 打开本项目的 [Gitee 页面](https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer)。
2. 点击 `克隆/下载` → `下载ZIP`。

下载完成后解压，不要只单独下载某一个文件。

## Windows 用户

1. 解压后进入文件夹，双击 `start.bat`。
2. 如果 Windows 弹出管理员权限提示，点”是”。
3. 在界面顶部选择 `Claude Code` 或 `Codex 桌面端`。
4. 点击 `开始安装`。
5. 点击 `打开令牌页面`，获取你的 2api 令牌。
6. 回到界面，把令牌粘贴进去。
7. 模型可以留空，留空会使用服务默认模型。
8. 点击 `一键配置` 或 `配置 Codex`。
9. 点击 `测试连接`。

看到”连接成功”后，就可以开始使用。

## macOS / Linux 用户

推荐方式 — 一行命令搞定（三选一）：

```bash
# Gitee 国内镜像 (推荐)
curl -fsSL https://gitee.com/wanghaojieaiyue/claude-codex-2api-installer/raw/main/setup.sh | bash

# GitHub
curl -fsSL https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh | bash

# GitHub 加速
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/w03anghj35/claude-codex-2api-installer/main/setup.sh | bash
```

按照提示选择模型、粘贴令牌就完成了。

如果你下载了 ZIP 包，也可以手动运行：

```bash
chmod +x setup.sh
./setup.sh
```

如果只需要修改 API 配置：

```bash
chmod +x configure-api.sh
./configure-api.sh
```

## 接口地址

工具已经内置默认地址：

| 工具 | 默认接口地址 |
|------|--------------|
| Claude Code | `https://2api.cloud/` |
| Codex | `https://2api.cloud/v1` |

一般不需要修改。如果你的服务商给了别的接口地址，再在界面里手动改。

## 启动 Claude Code

配置成功后，打开新的终端窗口，运行：

```bash
claude
```

也可以测试一句：

```bash
claude -p "请只回复：连接成功" --output-format text
```

## 启动 Codex

配置成功后，打开新的终端窗口，运行：

```bash
codex
```

也可以测试一句：

```bash
codex exec "请只回复：连接成功"
```

## 文件说明

| 文件 | 平台 | 说明 |
|------|------|------|
| `start.bat` | Windows | 图形界面入口，普通用户双击这个文件 |
| `start.sh` | macOS/Linux | 命令行入口脚本 |
| `ClaudeCodeGUI.ps1` | Windows | 图形界面主脚本 |
| `一键安装.bat` | Windows | 旧版 Claude Code 命令行安装入口 |
| `配置API.bat` | Windows | 旧版 Claude Code 命令行配置入口 |
| `install.ps1` | Windows | Claude Code 安装脚本 |
| `install.sh` | macOS/Linux | Claude Code 安装脚本 |
| `configure-api.ps1` | Windows | Claude Code 命令行配置脚本 |
| `configure-api.sh` | macOS/Linux | Claude Code 命令行配置脚本 |
| `ClaudeCodeInstaller.iss` | Windows | Inno Setup 打包脚本 |
| `generate_guide.py` | 全平台 | 生成 Word/PDF 说明书 |
| `requirements.txt` | 全平台 | 生成说明书需要的 Python 依赖 |
| `Claude Code 使用说明.docx` | - | Word 说明书 |
| `Claude Code 使用说明.pdf` | - | PDF 说明书 |

## 上传 GitHub 前注意

不要上传你的个人密钥和本机配置：

- 不要上传 `%USERPROFILE%\.claude\settings.json` (Windows) 或 `~/.claude/settings.json` (macOS/Linux)
- 不要上传 `%USERPROFILE%\.codex\auth.json` (Windows) 或 `~/.codex/auth.json` (macOS/Linux)
- 不要把自己的 2api 令牌写进 README、脚本或截图

本项目目录里的脚本不会保存你的令牌；令牌只会写到当前用户目录下的 Claude/Codex 配置文件。

## 常见问题

### Windows: 双击没有反应

右键 `start.bat`，选择”以管理员身份运行”。

### Windows: 提示 PowerShell 禁止运行脚本

本工具的 bat 会自动使用：

```powershell
-ExecutionPolicy Bypass
```

如果仍然失败，请右键以管理员身份运行。

### macOS/Linux: Permission denied

需要先添加执行权限：

```bash
chmod +x start.sh install.sh configure-api.sh
```

### macOS/Linux: Node.js 安装失败

macOS 推荐先安装 Homebrew：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Linux 如果包管理器安装失败，脚本会尝试从 npmmirror 下载二进制包。也可以手动安装：

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs
```

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

## 打包 macOS/Linux 分发包

在 Windows 上运行：

```powershell
powershell -File build-package.ps1
```

或者在 macOS/Linux 上运行：

```bash
chmod +x build-package.sh
./build-package.sh
```

生成的压缩包在 `Output` 目录，用户下载后解压即可使用：

```bash
unzip ClaudeCode-v1.0.0-unix.zip
chmod +x *.sh
./start.sh
```

## 免责声明

本工具只负责安装和写入本机配置。Claude Code、Codex、2api 账号、模型订阅和费用由对应服务方负责。请妥善保管自己的令牌。

