@echo off
setlocal
title SLXDPI
rem ============================================================
rem  SLXDPI - control menu. Right-click > Run as administrator.
rem  Reads the real state each time and only offers actions that
rem  make sense (no reinstall when installed, no stop when stopped).
rem ============================================================
net session >nul 2>&1
if errorlevel 1 goto :notadmin

set "DEST=C:\slxdpi"

:menu
set "INST=0"
set "RUN=0"
set "DNS=0"
sc query SLXDPI >nul 2>&1 && set "INST=1"
sc query SLXDPI 2>nul | find "RUNNING" >nul && set "RUN=1"
sc query dnscrypt-proxy 2>nul | find "RUNNING" >nul && set "DNS=1"

cls
echo.
echo   SLXDPI   Turkey DPI bypass  -  Discord, Roblox  -  payments untouched
echo   ------------------------------------------------------------------
if "%INST%"=="0" echo   Service : NOT INSTALLED
if "%INST%%RUN%"=="11" echo   Service : RUNNING
if "%INST%%RUN%"=="10" echo   Service : STOPPED
if "%DNS%"=="1" (echo   DNS     : ENCRYPTED) else (echo   DNS     : normal ^(not encrypted^))
if exist "%DEST%\tuned.txt" (echo   Method  : auto-detected for this network) else (echo   Method  : default)
echo   ------------------------------------------------------------------
echo.
if "%INST%"=="0" (echo   [1] Install) else (echo   [1] Install            - already installed)
if "%INST%%RUN%"=="10" (echo   [2] Start) else (echo   [2] Start              - not available)
if "%RUN%"=="1" (echo   [3] Stop) else (echo   [3] Stop               - not running)
if "%INST%"=="1" (echo   [4] Re-detect method) else (echo   [4] Re-detect method   - install first)
echo   [5] Diagnostics
if "%INST%"=="1" (echo   [6] Uninstall) else (echo   [6] Uninstall          - not installed)
echo   [0] Exit
echo.
choice /c 1234560 /n /m "  Select: "
if errorlevel 7 goto :eof
if errorlevel 6 goto :do_uninstall
if errorlevel 5 goto :do_status
if errorlevel 4 goto :do_autotune
if errorlevel 3 goto :do_stop
if errorlevel 2 goto :do_start
goto :do_install

:do_install
if "%INST%"=="1" goto :say_installed
set "INSTALLER=%~dp0install.bat"
if not exist "%INSTALLER%" set "INSTALLER=%DEST%\install.bat"
if not exist "%INSTALLER%" goto :no_installer
call "%INSTALLER%"
goto :menu

:do_start
if "%INST%"=="0" goto :say_notinstalled
if "%RUN%"=="1" goto :say_running
call "%DEST%\start.bat"
goto :menu

:do_stop
if "%RUN%"=="0" goto :say_notrunning
call "%DEST%\stop.bat"
goto :menu

:do_autotune
if "%INST%"=="0" goto :say_notinstalled
call "%DEST%\autotune.bat"
goto :menu

:do_status
if exist "%DEST%\status.bat" (call "%DEST%\status.bat") else (call "%~dp0status.bat")
goto :menu

:do_uninstall
if "%INST%"=="0" goto :say_notinstalled
echo.
choice /c YN /n /m "  Remove SLXDPI and restore normal DNS? [Y/N] "
if errorlevel 2 goto :menu
call "%DEST%\uninstall.bat"
goto :menu

:say_installed
call :msg "Already installed. Use Uninstall first if you want a clean reinstall."
goto :menu
:say_notinstalled
call :msg "SLXDPI is not installed yet. Choose [1] Install."
goto :menu
:say_running
call :msg "Already running."
goto :menu
:say_notrunning
call :msg "Already stopped."
goto :menu
:no_installer
call :msg "install.bat not found. Download the ZIP from github.com/thesleax/slxdpi and run slxdpi.cmd from inside it."
goto :menu

:msg
echo.
echo   %~1
timeout /t 3 /nobreak >nul
exit /b 0

:notadmin
echo.
echo   Run this file as ADMINISTRATOR:
echo   right-click slxdpi.cmd ^> "Run as administrator"
echo.
pause
exit /b 1
