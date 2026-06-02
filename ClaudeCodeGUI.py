#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Claude Code / Codex 图形安装配置助手
支持 Windows / macOS / Linux
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import threading
import subprocess
import sys
import os
import json
import platform
import urllib.request
import shutil
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# 全局配置
# ---------------------------------------------------------------------------
NODEJS_VERSION   = "22.13.1"
NODEJS_URL_WIN   = f"https://npmmirror.com/mirrors/node/v{NODEJS_VERSION}/node-v{NODEJS_VERSION}-x64.msi"
NODEJS_URL_MAC   = f"https://npmmirror.com/mirrors/node/v{NODEJS_VERSION}/node-v{NODEJS_VERSION}-pkg"
GIT_VERSION      = "2.47.1"
GIT_URL_WIN      = f"https://registry.npmmirror.com/-/binary/git-for-windows/v{GIT_VERSION}.windows.1/Git-{GIT_VERSION}-64-bit.exe"
NPM_MIRROR       = "https://registry.npmmirror.com"
DEFAULT_BASE_URL = "https://2api.cloud"
TOKEN_URL        = "https://2api.cloud/console/token"

SETTINGS_DIR  = Path.home() / ".claude"
SETTINGS_PATH = SETTINGS_DIR / "settings.json"
CODEX_HOME    = Path.home() / ".codex"

IS_WIN = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"

# ---------------------------------------------------------------------------
# 辅助函数
# ---------------------------------------------------------------------------
def is_admin():
    if IS_WIN:
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except:
            return False
    else:
        return os.geteuid() == 0

def cmd_exists(cmd):
    return shutil.which(cmd) is not None

def run_cmd(cmd, shell=True):
    try:
        result = subprocess.run(cmd, shell=shell, capture_output=True, text=True, timeout=300)
        return result.returncode == 0, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def save_claude_config(api_key, model):
    SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
    if model:
        obj = {
            "env": {
                "ANTHROPIC_AUTH_TOKEN":           api_key,
                "ANTHROPIC_BASE_URL":             DEFAULT_BASE_URL,
                "ANTHROPIC_DEFAULT_OPUS_MODEL":   model,
                "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
                "ANTHROPIC_DEFAULT_HAIKU_MODEL":  model,
                "ANTHROPIC_MODEL":                model,
            }
        }
    else:
        obj = {
            "env": {
                "ANTHROPIC_AUTH_TOKEN": api_key,
                "ANTHROPIC_BASE_URL":   DEFAULT_BASE_URL,
            }
        }
    with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)

def save_codex_config(api_key, model):
    CODEX_HOME.mkdir(parents=True, exist_ok=True)
    auth = {"OPENAI_API_KEY": api_key}
    with open(CODEX_HOME / "auth.json", "w", encoding="utf-8") as f:
        json.dump(auth, f, indent=2)
    cfg = f'model_provider = "88code"\n'
    if model:
        cfg += f'model = "{model}"\n'
    cfg += f'\n[model_providers.88code]\nname = "88code"\nbase_url = "{DEFAULT_BASE_URL}/v1"\nwire_api = "responses"\nrequires_openai_auth = true\n'
    with open(CODEX_HOME / "config.toml", "w", encoding="utf-8") as f:
        f.write(cfg)

# ---------------------------------------------------------------------------
# 主窗口
# ---------------------------------------------------------------------------
class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Claude Code / Codex 安装配置助手")
        self.resizable(True, True)
        self.minsize(780, 680)
        self._admin = is_admin()
        self._build_ui()
        self._check_status()

    def _build_ui(self):
        self.configure(bg="#f5f5f5")
        pad = dict(padx=12, pady=4)

        # 标题
        tk.Label(self, text="Claude Code / Codex 安装配置助手",
                 font=("", 14, "bold"), bg="#f5f5f5").pack(anchor="w", padx=16, pady=(12, 4))

        # 模式选择
        grp_mode = ttk.LabelFrame(self, text="模式选择")
        grp_mode.pack(fill="x", padx=12, pady=4)
        self._mode = tk.StringVar(value="full")
        ttk.Radiobutton(grp_mode, text="完整安装 (Node.js + Git + Claude Code + 配置 API)",
                        variable=self._mode, value="full",
                        command=self._on_mode_change).pack(side="left", padx=12, pady=6)
        ttk.Radiobutton(grp_mode, text="仅配置 / 更换 API 令牌",
                        variable=self._mode, value="api_only",
                        command=self._on_mode_change).pack(side="left", padx=12, pady=6)

        # 工具选择
        self._grp_tool = ttk.LabelFrame(self, text="步骤 1 — 选择要安装的工具")
        self._grp_tool.pack(fill="x", padx=12, pady=4)
        self._tool = tk.StringVar(value="claude")
        ttk.Radiobutton(self._grp_tool, text="Claude Code (推荐)", variable=self._tool, value="claude").pack(side="left", padx=12, pady=6)
        ttk.Radiobutton(self._grp_tool, text="Codex",              variable=self._tool, value="codex").pack(side="left", padx=12, pady=6)
        ttk.Radiobutton(self._grp_tool, text="两个都装",            variable=self._tool, value="both").pack(side="left", padx=12, pady=6)

        # 安装按钮
        self._grp_install = ttk.LabelFrame(self, text="步骤 2 — 安装环境")
        self._grp_install.pack(fill="x", padx=12, pady=4)
        self._btn_install = ttk.Button(self._grp_install, text="开始安装", command=self._on_install)
        self._btn_install.pack(side="left", padx=12, pady=8)
        self._lbl_install_hint = tk.Label(self._grp_install,
            text="检测已安装的组件，只安装缺失项。仅配置模式下此步骤跳过。",
            fg="gray", bg="#f5f5f5")
        self._lbl_install_hint.pack(side="left", padx=4)

        # API 配置
        grp_api = ttk.LabelFrame(self, text="步骤 3 — 配置 API 令牌")
        grp_api.pack(fill="x", padx=12, pady=4)

        row1 = tk.Frame(grp_api, bg="#f5f5f5")
        row1.pack(fill="x", padx=8, pady=4)
        tk.Label(row1, text="令牌:", bg="#f5f5f5", width=6, anchor="e").pack(side="left")
        self._txt_token = ttk.Entry(row1, show="*", width=48)
        self._txt_token.pack(side="left", padx=4)
        self._chk_show_var = tk.BooleanVar()
        ttk.Checkbutton(row1, text="显示", variable=self._chk_show_var,
                        command=self._toggle_token).pack(side="left")
        ttk.Button(row1, text="获取令牌", command=lambda: self._open_url(TOKEN_URL)).pack(side="left", padx=8)

        row2 = tk.Frame(grp_api, bg="#f5f5f5")
        row2.pack(fill="x", padx=8, pady=4)
        tk.Label(row2, text="模型:", bg="#f5f5f5", width=6, anchor="e").pack(side="left")
        self._txt_model = ttk.Entry(row2, width=48, foreground="gray")
        self._txt_model.insert(0, "留空使用服务默认（推荐）")
        self._txt_model.bind("<FocusIn>", self._on_model_focus_in)
        self._txt_model.bind("<FocusOut>", self._on_model_focus_out)
        self._txt_model.pack(side="left", padx=4)

        row3 = tk.Frame(grp_api, bg="#f5f5f5")
        row3.pack(fill="x", padx=8, pady=(0, 8))
        self._btn_configure = ttk.Button(row3, text="写入配置", command=self._on_configure)
        self._btn_configure.pack(side="left", padx=0)
        self._btn_test = ttk.Button(row3, text="测试连接", command=self._on_test)
        self._btn_test.pack(side="left", padx=8)
        ttk.Button(row3, text="查看配置", command=self._on_view_config).pack(side="left", padx=8)

        # 日志
        grp_log = ttk.LabelFrame(self, text="日志")
        grp_log.pack(fill="both", expand=True, padx=12, pady=4)

        log_toolbar = tk.Frame(grp_log, bg="#f5f5f5")
        log_toolbar.pack(fill="x", padx=4, pady=(4, 0))
        ttk.Button(log_toolbar, text="编辑 Claude 配置", command=lambda: self._edit_config("claude")).pack(side="left", padx=2)
        ttk.Button(log_toolbar, text="编辑 Codex 配置", command=lambda: self._edit_config("codex")).pack(side="left", padx=2)
        ttk.Button(log_toolbar, text="保存配置", command=self._save_config).pack(side="left", padx=2)
        ttk.Button(log_toolbar, text="清空日志", command=self._clear_log).pack(side="left", padx=2)

        self._txt_log = scrolledtext.ScrolledText(grp_log, height=10,
                                                   font=("Courier", 9), bg="#1e1e1e", fg="#d4d4d4")
        self._txt_log.pack(fill="both", expand=True, padx=4, pady=4)
        self._editing_config = None  # 当前正在编辑的配置文件路径

    def _on_mode_change(self):
        api_only = self._mode.get() == "api_only"
        state = "disabled" if api_only else "normal"
        for w in self._grp_tool.winfo_children():
            w.configure(state=state)
        self._btn_install.configure(state=state)

    def _toggle_token(self):
        self._txt_token.configure(show="" if self._chk_show_var.get() else "*")

    def _on_model_focus_in(self, event):
        if self._txt_model.get() == "留空使用服务默认（推荐）":
            self._txt_model.delete(0, "end")
            self._txt_model.configure(foreground="black")

    def _on_model_focus_out(self, event):
        if not self._txt_model.get().strip():
            self._txt_model.insert(0, "留空使用服务默认（推荐）")
            self._txt_model.configure(foreground="gray")

    def _open_url(self, url):
        import webbrowser
        webbrowser.open(url)

    def _log(self, msg):
        ts = datetime.now().strftime("%H:%M:%S")
        self._txt_log.insert("end", f"[{ts}] {msg}\n")
        self._txt_log.see("end")

    def _clear_log(self):
        self._txt_log.delete("1.0", "end")
        self._editing_config = None

    def _view_config(self):
        """用系统编辑器打开配置文件"""
        files = []
        if SETTINGS_PATH.exists():
            files.append(("Claude Code", str(SETTINGS_PATH)))
        if (CODEX_HOME / "config.toml").exists():
            files.append(("Codex config.toml", str(CODEX_HOME / "config.toml")))
        if (CODEX_HOME / "auth.json").exists():
            files.append(("Codex auth.json", str(CODEX_HOME / "auth.json")))

        if not files:
            messagebox.showinfo("提示", "未找到配置文件，请先写入配置。")
            return

        for name, path in files:
            if IS_WIN:
                subprocess.Popen(["notepad", path])
            elif IS_MAC:
                subprocess.Popen(["open", "-e", path])
            else:
                subprocess.Popen(["xdg-open", path])
            self._log(f"已打开 {name}: {path}")

    def _edit_config(self, config_type):
        """在日志区编辑配置文件"""
        if config_type == "claude":
            path = SETTINGS_PATH
        elif config_type == "codex":
            path = CODEX_HOME / "config.toml"
        else:
            return

        if not path.exists():
            messagebox.showwarning("文件不存在", f"配置文件不存在: {path}\n请先写入配置。")
            return

        self._txt_log.delete("1.0", "end")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        self._txt_log.insert("1.0", content)
        self._editing_config = path
        self._log(f"\n--- 正在编辑: {path} ---")
        self._log("编辑完成后点击「保存配置」")

    def _save_config(self):
        """保存从日志区编辑的配置"""
        if not self._editing_config:
            messagebox.showwarning("提示", "当前没有打开配置文件编辑。\n请先点击「编辑 Claude 配置」或「编辑 Codex 配置」。")
            return

        content = self._txt_log.get("1.0", "end-1c")
        # 移除日志提示行
        lines = content.split("\n")
        lines = [l for l in lines if not l.startswith("---") and not l.startswith("编辑完成后")]
        content = "\n".join(lines).strip()

        try:
            with open(self._editing_config, "w", encoding="utf-8") as f:
                f.write(content)
            messagebox.showinfo("成功", f"配置已保存到:\n{self._editing_config}")
            self._clear_log()
            self._log(f"配置已保存: {self._editing_config}")
        except Exception as e:
            messagebox.showerror("保存失败", f"保存配置失败:\n{e}")

    def _on_view_config(self):
        self._view_config()

    def _check_status(self):
        status = []
        if cmd_exists("node"):
            ok, ver = run_cmd("node --version")
            status.append(f"Node.js {ver.strip()}")
        if cmd_exists("git"):
            ok, ver = run_cmd("git --version")
            status.append(ver.strip())
        if cmd_exists("claude"):
            status.append("Claude Code 已安装")
        if cmd_exists("codex"):
            status.append("Codex CLI 已安装")
        self._log("界面已启动。请选择模式和工具，然后按步骤操作。")
        if not self._admin:
            self._log("[提示] 当前非管理员运行，安装环境需以管理员/sudo 身份启动。配置 API 不受影响。")
        if status:
            self._log("当前已安装: " + " | ".join(status))

    # -----------------------------------------------------------------------
    # 安装
    # -----------------------------------------------------------------------
    def _on_install(self):
        if not self._admin:
            messagebox.showwarning("需要管理员权限",
                "安装 Node.js 和 Git 需要管理员权限。\n\n"
                "请以管理员身份重新运行本程序，或者选择「仅配置 API」模式。")
            return
        self._btn_install.configure(state="disabled")
        threading.Thread(target=self._do_install, daemon=True).start()

    def _do_install(self):
        tool = self._tool.get()
        install_claude = tool in ("claude", "both")
        install_codex  = tool in ("codex",  "both")

        # Node.js
        if not cmd_exists("node"):
            self._log("正在安装 Node.js ...")
            if IS_WIN:
                tmp = Path(os.environ["TEMP"]) / "nodejs.msi"
                urllib.request.urlretrieve(NODEJS_URL_WIN, tmp)
                ok, out = run_cmd(f'msiexec /i "{tmp}" /qn /norestart')
                self._log("Node.js 安装完成" if ok else f"Node.js 安装失败: {out}")
            elif IS_MAC:
                ok, out = run_cmd("brew install node")
                self._log("Node.js 安装完成" if ok else f"Node.js 安装失败: {out}")
            else:
                ok, out = run_cmd("sudo apt-get install -y nodejs npm")
                self._log("Node.js 安装完成" if ok else f"Node.js 安装失败: {out}")
        else:
            ok, ver = run_cmd("node --version")
            self._log(f"Node.js {ver.strip()} 已安装，跳过。")

        # Git
        if not cmd_exists("git"):
            self._log("正在安装 Git ...")
            if IS_WIN:
                tmp = Path(os.environ["TEMP"]) / "git.exe"
                urllib.request.urlretrieve(GIT_URL_WIN, tmp)
                ok, out = run_cmd(f'"{tmp}" /VERYSILENT /NORESTART')
                self._log("Git 安装完成" if ok else f"Git 安装失败: {out}")
            elif IS_MAC:
                ok, out = run_cmd("brew install git")
                self._log("Git 安装完成" if ok else f"Git 安装失败: {out}")
            else:
                ok, out = run_cmd("sudo apt-get install -y git")
                self._log("Git 安装完成" if ok else f"Git 安装失败: {out}")
        else:
            ok, ver = run_cmd("git --version")
            self._log(f"{ver.strip()} 已安装，跳过。")

        # npm 镜像
        if cmd_exists("npm"):
            run_cmd(f"npm config set registry {NPM_MIRROR}")
            self._log(f"npm 镜像已设置: {NPM_MIRROR}")

        # Claude Code
        if install_claude:
            if cmd_exists("claude"):
                ok, ver = run_cmd("claude --version")
                self._log(f"Claude Code {ver.strip()} 已安装，跳过。")
            else:
                self._log("正在安装 Claude Code ...")
                ok, out = run_cmd("npm install -g @anthropic-ai/claude-code")
                self._log("Claude Code 安装完成" if ok else f"Claude Code 安装失败: {out}")

        # Codex
        if install_codex:
            if cmd_exists("codex"):
                self._log("Codex CLI 已安装，跳过。")
            else:
                self._log("正在安装 Codex CLI ...")
                ok, out = run_cmd("npm install -g @openai/codex")
                self._log("Codex CLI 安装完成" if ok else f"Codex CLI 安装失败: {out}")

        self._log("=== 安装步骤完成，请继续配置 API 令牌 ===")
        self.after(0, lambda: self._btn_install.configure(state="normal"))

    # -----------------------------------------------------------------------
    # 写入配置
    # -----------------------------------------------------------------------
    def _on_configure(self):
        api_key = self._txt_token.get().strip()
        model   = self._txt_model.get().strip()

        # 过滤 placeholder 文本
        if model == "留空使用服务默认（推荐）":
            model = ""

        if not api_key:
            messagebox.showwarning("缺少令牌", "请先输入令牌。")
            return

        api_only = self._mode.get() == "api_only"
        tool = self._tool.get()
        install_claude = True if api_only else tool in ("claude", "both")
        install_codex  = False if api_only else tool in ("codex",  "both")

        try:
            if install_claude:
                save_claude_config(api_key, model)
                self._log(f"Claude Code 配置已写入: {SETTINGS_PATH}")
            if install_codex:
                save_codex_config(api_key, model)
                self._log(f"Codex 配置已写入: {CODEX_HOME}")
            self._log(f"模型: {'使用服务默认' if not model else model}")
            messagebox.showinfo("完成", "配置写入成功！")
        except Exception as e:
            self._log(f"[错误] 配置写入失败: {e}")

    # -----------------------------------------------------------------------
    # 测试连接
    # -----------------------------------------------------------------------
    def _on_test(self):
        api_key = self._txt_token.get().strip()
        if not api_key:
            messagebox.showwarning("缺少令牌", "请先输入令牌。")
            return
        self._btn_test.configure(state="disabled")
        self._log("正在测试 API 连接...")
        threading.Thread(target=self._do_test, args=(api_key,), daemon=True).start()

    def _do_test(self, api_key):
        try:
            import urllib.request, urllib.error
            req = urllib.request.Request(
                f"{DEFAULT_BASE_URL}/v1/models",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                self._log("[成功] API 连接测试通过！")
                self.after(0, lambda: messagebox.showinfo("测试通过", "API 连接测试成功！"))
        except Exception as e:
            self._log(f"[失败] API 连接测试失败: {e}")
            self.after(0, lambda: messagebox.showwarning("连接失败",
                f"API 连接失败。\n\n可能原因:\n  1. 令牌错误或已过期\n  2. 网络连接问题\n  3. API 服务暂时不可用"))
        finally:
            self.after(0, lambda: self._btn_test.configure(state="normal"))


if __name__ == "__main__":
    app = App()
    app.mainloop()
