@echo off
setlocal
title SLXDPI Setup
rem ============================================================
rem  SLXDPI - DPI bypass + DNS fix installer for Turkey
rem  Run as Administrator (right-click > Run as administrator)
rem  Works from the extracted folder OR as a lone install.bat.
rem  Flat goto/call flow on purpose: no logic inside ( ) blocks,
rem  so no batch variable-expansion surprises.
rem ============================================================

net session >nul 2>&1
if errorlevel 1 goto :notadmin

set "SRC=%~dp0"
set "DEST=C:\slxdpi"
set "BIN=%DEST%\bin"
set "WINWS=%BIN%\zapret-winws\winws.exe"
set "LISTDIR=%DEST%\lists"
set "SVC=SLXDPI"
set "DL=%DEST%\_dl"
set "LOG=%DEST%\install.log"

echo.
echo === Installing SLXDPI -^> %DEST% ===
if not exist "%DEST%" mkdir "%DEST%"
echo SLXDPI install %DATE% %TIME% > "%LOG%"
echo SRC=%SRC% >> "%LOG%"

rem --- [1/6] Defender exclusion (zapret/WinDivert = antivirus FALSE POSITIVE) ---
echo [1/6] Windows Defender exclusion for %DEST% ...
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%DEST%' -ErrorAction Stop } catch {}"
powershell -NoProfile -Command "try { if ((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains '%DEST%'){exit 0} else {exit 3} } catch { exit 0 }"
if errorlevel 3 goto :noexclusion
echo       OK

rem --- [2/6] Project files: copy from here, else fetch from GitHub ---
echo [2/6] Project files ...
if exist "%LISTDIR%\list-general.txt" goto :files_ok
set "PSRC=%SRC%"
if exist "%SRC%lists\list-general.txt" goto :copy_files
echo       not next to install.bat, fetching from GitHub ...
call :fetch "https://github.com/thesleax/slxdpi/archive/refs/heads/main.zip"
if errorlevel 1 goto :fail
set "PSRC=%DL%\slxdpi-main\"
:copy_files
echo       copying from %PSRC% >> "%LOG%"
xcopy "%PSRC%lists" "%LISTDIR%\" /e /i /y >> "%LOG%" 2>&1
for %%F in (strategy.cmd start.bat stop.bat status.bat uninstall.bat blockcheck.bat dns.bat) do copy /y "%PSRC%%%F" "%DEST%\" >> "%LOG%" 2>&1
:files_ok
if not exist "%LISTDIR%\list-general.txt" goto :nolist
if not exist "%DEST%\strategy.cmd" goto :nolist
echo       OK

rem --- [3/6] zapret binaries ---
echo [3/6] zapret engine ...
if exist "%WINWS%" goto :bin_ok
echo       downloading zapret Windows bundle (~20 MB) ...
call :fetch "https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip"
if errorlevel 1 goto :fail
xcopy "%DL%\zapret-win-bundle-master\*" "%BIN%\" /e /i /y >> "%LOG%" 2>&1
:bin_ok
if not exist "%WINWS%" goto :nowinws
rmdir /s /q "%DL%" >nul 2>&1
echo       OK

rem --- [4/6] Service (auto-start on boot). Space-free path -> no inner quotes ---
echo [4/6] Windows service ...
call "%DEST%\strategy.cmd"
set "ARGS=--wf-tcp=%SLX_WF_TCP% --wf-udp=%SLX_WF_UDP% %SLX_TCP% --new %SLX_QUIC% --new %SLX_VOICE%"
echo ARGS=%ARGS% >> "%LOG%"
sc stop %SVC% >nul 2>&1
sc delete %SVC% >nul 2>&1
sc create %SVC% binPath= "%WINWS% %ARGS%" start= auto DisplayName= "SLXDPI (DPI bypass)" >> "%LOG%" 2>&1
if errorlevel 1 goto :nosvc
sc description %SVC% "DPI bypass for Turkey: Discord, Roblox and blocked sites. Banking/payments are NOT affected." >nul
echo       OK

rem --- [5/6] DNS -> Cloudflare DoH (fixes Roblox image / DNS poisoning) ---
echo [5/6] Encrypted DNS ...
call "%DEST%\dns.bat" set

rem --- [6/6] Start ---
echo [6/6] Starting ...
sc start %SVC% >> "%LOG%" 2>&1
timeout /t 3 /nobreak >nul
sc query %SVC% | find "RUNNING" >nul
if errorlevel 1 goto :nostart
echo       OK

echo.
echo === INSTALL COMPLETE ===
echo  - Service: %SVC% (starts automatically on Windows boot)
echo  - On/Off: start.bat / stop.bat   Diagnose: status.bat   Remove: uninstall.bat
echo  - Not working? run blockcheck.bat (finds the right settings for your ISP)
echo.
echo  TEST: open Roblox (images should load), join a Discord voice channel.
echo        Banking/payments (3-D Secure) are NOT affected - not in the list.
echo  NOTE: do not run GoodbyeDPI at the same time.
echo.
pause
exit /b 0

rem ============================================================
rem  :fetch <url>  -> downloads and extracts into %DL%
rem  Uses built-in curl+tar (Win10 1803+), falls back to PowerShell.
rem ============================================================
:fetch
rmdir /s /q "%DL%" >nul 2>&1
mkdir "%DL%"
echo fetch %~1 >> "%LOG%"
where curl >nul 2>&1 || goto :fetch_ps
where tar  >nul 2>&1 || goto :fetch_ps
curl -fSL --retry 2 --connect-timeout 20 -o "%DL%\pkg.zip" "%~1" 2>> "%LOG%"
if errorlevel 1 goto :fetch_err
rem tar may warn on odd entries; success is judged by the files we need, not its exit code
tar -xf "%DL%\pkg.zip" -C "%DL%" >> "%LOG%" 2>&1
exit /b 0
:fetch_ps
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing '%~1' -OutFile '%DL%\pkg.zip' -ErrorAction Stop } catch { $_.Exception.Message | Add-Content -Path '%LOG%'; exit 1 }; try { Expand-Archive -LiteralPath '%DL%\pkg.zip' -DestinationPath '%DL%' -Force } catch { $_.Exception.Message | Add-Content -Path '%LOG%' }"
if errorlevel 1 goto :fetch_err
exit /b 0
:fetch_err
echo [ERROR] Download failed: %~1
echo         GitHub may be unreachable on your network. Details: %LOG%
exit /b 1

rem ============================================================
rem  Error exits
rem ============================================================
:notadmin
echo [ERROR] Run this file as ADMINISTRATOR.
echo         Right-click ^> "Run as administrator"
pause
exit /b 1

:noexclusion
echo.
echo [!] Could not add the Defender exclusion automatically
echo     ("Tamper Protection" is ON). Add it by hand once:
echo.
echo       Windows Security ^> Virus ^& threat protection ^> Manage settings
echo       ^> Exclusions ^> Add an exclusion ^> Folder ^> %DEST%
echo.
echo     Turkish: Windows Guvenligi ^> Virus ve tehdit korumasi ^>
echo     Ayarlari yonet ^> Dislamalar ^> Dislama ekle ^> Klasor ^> %DEST%
echo.
echo     Then run this installer again.
pause
exit /b 1

:nolist
echo [ERROR] Project files missing in %DEST%. Details: %LOG%
goto :fail

:nowinws
echo [ERROR] winws.exe missing after extract: %WINWS%
echo         Antivirus probably removed it: Windows Security ^> Protection history
echo         ^> allow/restore it, then run this installer again. Details: %LOG%
goto :fail

:nosvc
echo [ERROR] Could not create the Windows service. Details: %LOG%
goto :fail

:nostart
echo [ERROR] Service created but did not start. Run status.bat. Details: %LOG%
goto :fail

:fail
echo.
echo Install did not finish. Send the screen output + %LOG% for help.
pause
exit /b 1
