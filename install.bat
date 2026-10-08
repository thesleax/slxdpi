@echo off
setlocal enabledelayedexpansion
title SLXDPI Setup
rem ============================================================
rem  SLXDPI - DPI bypass + DNS fix installer for Turkey
rem  Run as Administrator (right-click > Run as administrator)
rem ============================================================

rem --- Admin check ---
net session >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Run this file as ADMINISTRATOR.
  echo         Right-click ^> "Run as administrator"
  pause & exit /b 1
)

set "SRC=%~dp0"
set "DEST=C:\slxdpi"
set "BIN=%DEST%\bin"
set "WINWS=%BIN%\zapret-winws\winws.exe"
set "LISTDIR=%DEST%\lists"
set "SVC=SLXDPI"

echo.
echo === Installing SLXDPI -> %DEST% ===

rem --- 1) Copy files to a fixed, space-free path ---
if /i not "%SRC%"=="%DEST%\" (
  if not exist "%DEST%" mkdir "%DEST%"
  xcopy "%SRC%lists"        "%LISTDIR%\"   /e /i /y >nul
  copy  /y "%SRC%strategy.cmd" "%DEST%\"   >nul
  copy  /y "%SRC%*.bat"        "%DEST%\"   >nul
)

rem --- 2) Download zapret binaries (if missing) ---
if not exist "%WINWS%" (
  echo [*] Downloading zapret Windows bundle...
  set "ZIP=%TEMP%\slxdpi-zapret.zip"
  set "EX=%TEMP%\slxdpi-zapret"
  powershell -NoProfile -Command ^
    "try { Invoke-WebRequest -UseBasicParsing 'https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip' -OutFile '%ZIP%'; Expand-Archive -Force '%ZIP%' '%EX%' } catch { exit 1 }"
  if errorlevel 1 (
    echo [ERROR] Download failed. GitHub may be blocked on your network.
    echo         Download manually: https://github.com/bol-van/zapret-win-bundle
    echo         Extract its folders into %BIN% and run this again.
    pause & exit /b 1
  )
  if not exist "%BIN%" mkdir "%BIN%"
  xcopy "%EX%\zapret-win-bundle-master\*" "%BIN%\" /e /i /y >nul
  del "%ZIP%" >nul 2>&1
)
if not exist "%WINWS%" (
  echo [ERROR] winws.exe not found: %WINWS%
  pause & exit /b 1
)

rem --- 3) Load strategy and build winws arguments ---
call "%DEST%\strategy.cmd"
set "ARGS=--wf-tcp=%SLX_WF_TCP% --wf-udp=%SLX_WF_UDP% %SLX_TCP% --new %SLX_QUIC% --new %SLX_VOICE%"

rem --- 4) Remove any existing service ---
sc stop %SVC% >nul 2>&1
sc delete %SVC% >nul 2>&1

rem --- 5) Create service (auto-start on boot). Space-free path -> no inner quotes. ---
sc create %SVC% binPath= "%WINWS% %ARGS%" start= auto DisplayName= "SLXDPI (DPI bypass)" >nul
if errorlevel 1 ( echo [ERROR] Could not create the service. & pause & exit /b 1 )
sc description %SVC% "DPI bypass for Turkey: Discord, Roblox and blocked sites. Banking/payments are NOT affected." >nul

rem --- 6) Switch DNS to DoH (Cloudflare) -> fixes Roblox image/DNS poisoning ---
call "%DEST%\dns.bat" set

rem --- 7) Start ---
sc start %SVC% >nul
echo.
echo === INSTALL COMPLETE ===
echo  - Service: %SVC% (starts automatically on Windows boot)
echo  - On/Off: start.bat / stop.bat   Status: status.bat   Remove: uninstall.bat
echo  - Not working? run blockcheck.bat (finds the right settings for your ISP)
echo.
echo  TEST: open Roblox (images should load), join a Discord voice channel.
echo        Banking/payments (3-D Secure) are NOT affected - not in the list.
echo.
pause
endlocal
