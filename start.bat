@echo off
chcp 65001 >nul 2>&1
title Claude Code Installer

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ClaudeCodeGUI.ps1"
if errorlevel 1 pause
