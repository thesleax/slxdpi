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
set "DL=%DEST%\_dl"
set "ZIP=%DL%\bundle.zip"

echo.
echo === Installing SLXDPI -> %DEST% ===
if not exist "%DEST%" mkdir "%DEST%"

rem --- 0) Windows Defender exclusion. zapret/WinDivert is flagged as a FALSE
rem     POSITIVE (Trojan:Win32/...) because it inspects packets. Excluding our
rem     own folder stops Defender from deleting winws.exe mid-install. ---
echo [*] Adding Windows Defender exclusion for %DEST% ...
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%DEST%' -ErrorAction Stop } catch {}"

rem --- 1) Ensure project files are in DEST.
rem     If run from the extracted folder, copy the siblings. If run standalone
rem     (just install.bat), fetch the project from GitHub. Either way works. ---
if not exist "%LISTDIR%\list-general.txt" (
  if exist "%SRC%lists\list-general.txt" (
    xcopy "%SRC%lists" "%LISTDIR%\" /e /i /y >nul
    for %%F in (strategy.cmd start.bat stop.bat status.bat uninstall.bat blockcheck.bat dns.bat) do if exist "%SRC%%%F" copy /y "%SRC%%%F" "%DEST%\" >nul
  ) else (
    echo [*] Fetching SLXDPI project files from GitHub...
    rmdir /s /q "%DL%" >nul 2>&1
    mkdir "%DL%"
    powershell -NoProfile -Command ^
      "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing 'https://github.com/thesleax/slxdpi/archive/refs/heads/main.zip' -OutFile '%DL%\proj.zip'; Expand-Archive -Force -LiteralPath '%DL%\proj.zip' -DestinationPath '%DL%' } catch { exit 1 }"
    if errorlevel 1 (
      echo [ERROR] Could not fetch project files from GitHub.
      echo         Extract the slxdpi ZIP fully and run install.bat from inside it.
      pause & exit /b 1
    )
    xcopy "%DL%\slxdpi-main\lists" "%LISTDIR%\" /e /i /y >nul
    for %%F in (strategy.cmd start.bat stop.bat status.bat uninstall.bat blockcheck.bat dns.bat) do copy /y "%DL%\slxdpi-main\%%F" "%DEST%\" >nul
    rmdir /s /q "%DL%" >nul 2>&1
  )
)

rem --- 2) Download zapret binaries INTO the excluded folder (if missing) ---
if not exist "%WINWS%" (
  echo [*] Downloading zapret Windows bundle...
  rmdir /s /q "%DL%" >nul 2>&1
  mkdir "%DL%"
  powershell -NoProfile -Command ^
    "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing 'https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip' -OutFile '%ZIP%'; Expand-Archive -Force -LiteralPath '%ZIP%' -DestinationPath '%DL%' } catch { exit 1 }"
  if errorlevel 1 (
    echo [ERROR] Download failed. GitHub may be blocked, or antivirus deleted it.
    echo         Manual fix: download https://github.com/bol-van/zapret-win-bundle
    echo         (Code ^> Download ZIP^), then copy its inner folders into %BIN%
    echo         and run this again. See README "Antivirus" section.
    pause & exit /b 1
  )
  if not exist "%BIN%" mkdir "%BIN%"
  xcopy "%DL%\zapret-win-bundle-master\*" "%BIN%\" /e /i /y >nul
  rmdir /s /q "%DL%" >nul 2>&1
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
