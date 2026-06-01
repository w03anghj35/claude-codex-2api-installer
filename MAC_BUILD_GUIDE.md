# Mac 用户打包说明

## 前提条件

确保你的 Mac 已安装：
- Python 3.8+
- pip3

## 打包步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/w03anghj35/claude-codex-2api-installer.git
   cd claude-codex-2api-installer
   ```

2. **运行打包脚本**
   ```bash
   chmod +x build-mac.sh
   ./build-mac.sh
   ```

3. **等待打包完成**
   - 脚本会自动安装 pyinstaller（如果没有）
   - 打包完成后会在 `Output/` 目录生成 `ClaudeCode-Setup-mac`

4. **发送给项目维护者**
   - 将 `Output/ClaudeCode-Setup-mac` 文件发送给项目维护者
   - 或者直接上传到 GitHub Release

## 测试打包结果

打包完成后可以先测试：
```bash
./Output/ClaudeCode-Setup-mac
```

应该会弹出图形界面。

## 常见问题

**Q: 提示 "无法打开，因为无法验证开发者"**

A: 在终端运行：
```bash
xattr -cr Output/ClaudeCode-Setup-mac
```

**Q: Python 版本太低**

A: 升级 Python：
```bash
brew upgrade python3
```

## 联系方式

如有问题，请在 GitHub Issues 提问。
