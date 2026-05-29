@echo off
chcp 65001 >nul 2>&1
title Claude Code 安装与 API 配置助手

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaudeCodeGUI.ps1"
