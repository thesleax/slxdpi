@echo off
rem ============================================================
rem  SLXDPI - auto-find a DPI-bypass setting that works on YOUR ISP
rem  Run this if the default strategy doesn't work.
rem  When asked for a test domain, try:
rem     discord.com , tr.rbxcdn.com , www.roblox.com
rem  Paste the resulting "winws ... --dpi-desync=..." line into strategy.cmd.
rem ============================================================
net session >nul 2>&1 || ( echo Run as administrator. & pause & exit /b 1 )
set "BC=C:\slxdpi\bin\blockcheck\blockcheck.cmd"
if not exist "%BC%" set "BC=%~dp0bin\blockcheck\blockcheck.cmd"
if not exist "%BC%" ( echo [ERROR] blockcheck not found. Run install.bat first. & pause & exit /b 1 )
call "%BC%"
pause
