# Linux 用户打包说明

## 前提条件

确保你的 Linux 已安装：
- Python 3.8+
- pip3
- python3-tk

## 打包步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/w03anghj35/claude-codex-2api-installer.git
   cd claude-codex-2api-installer
   ```

2. **运行打包脚本**
   ```bash
   chmod +x build-linux.sh
   ./build-linux.sh
   ```

3. **等待打包完成**
   - 脚本会自动安装 pyinstaller（如果没有）
   - 打包完成后会在 `Output/` 目录生成 `ClaudeCode-Setup-linux`

4. **发送给项目维护者**
   - 将 `Output/ClaudeCode-Setup-linux` 文件发送给项目维护者
   - 或者直接上传到 GitHub Release

## 测试打包结果

打包完成后可以先测试：
```bash
./Output/ClaudeCode-Setup-linux
```

应该会弹出图形界面。

## 常见问题

**Q: 提示缺少 tkinter**

A: 安装 python3-tk：
```bash
sudo apt-get install python3-tk
```

**Q: Python 版本太低**

A: 升级 Python：
```bash
sudo apt-get update
sudo apt-get install python3.10
```

**Q: 不想打包，直接运行**

A: 可以直接运行 Python 脚本：
```bash
python3 ClaudeCodeGUI.py
```

## 联系方式

如有问题，请在 GitHub Issues 提问。
