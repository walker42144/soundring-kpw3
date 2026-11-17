@echo off
cd /d "%~dp0"
py -3 config_gui.py
if errorlevel 1 pause
