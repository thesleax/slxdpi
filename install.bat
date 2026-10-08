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
set "DCVER=2.1.18"
set "DCX=%BIN%\dnscrypt\dnscrypt-proxy.exe"

echo.
echo === Installing SLXDPI -^> %DEST% ===

rem --- C:\slxdpi must be a real, writable folder. A same-named FILE or a
rem     broken link makes "if exist" true while every write fails with
rem     "path not found". Detect that, move it aside, recreate. ---
if exist "%DEST%\*" goto :dest_check
if not exist "%DEST%" goto :dest_make
echo [!] %DEST% exists but is not a normal folder:
dir C:\ /a | find /i "slxdpi"
set "OLDNAME=slxdpi.old-%RANDOM%"
echo     renaming it to C:\%OLDNAME% and creating a fresh folder ...
ren "%DEST%" "%OLDNAME%"
:dest_make
mkdir "%DEST%"
:dest_check
type nul > "%DEST%\.write-test" 2>nul
if not exist "%DEST%\.write-test" goto :dest_unwritable
del "%DEST%\.write-test" >nul 2>&1

echo SLXDPI install %DATE% %TIME% > "%LOG%"
echo SRC=%SRC% >> "%LOG%"

rem --- [1/7] Defender exclusion (zapret/WinDivert = antivirus FALSE POSITIVE) ---
echo [1/7] Windows Defender exclusion for %DEST% ...
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%DEST%' -ErrorAction Stop } catch {}"
powershell -NoProfile -Command "try { if ((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains '%DEST%'){exit 0} else {exit 3} } catch { exit 0 }"
if errorlevel 3 goto :noexclusion
echo       OK

rem --- [2/7] Project files: always refreshed (old installs leave stale scripts).
rem     Copied from next to install.bat if complete, else fetched from GitHub.
rem     Exception: list-general.txt is kept if present (user-added sites). ---
echo [2/7] Project files ...
set "PSRC=%SRC%"
if exist "%SRC%dnscrypt-proxy.toml" goto :copy_files
echo       not next to install.bat, fetching from GitHub ...
call :fetch "https://github.com/thesleax/slxdpi/archive/refs/heads/main.zip"
if errorlevel 1 goto :fail
set "PSRC=%DL%\slxdpi-main\"
:copy_files
echo       copying from %PSRC% >> "%LOG%"
if not exist "%LISTDIR%" mkdir "%LISTDIR%"
copy /y "%PSRC%lists\strategies.txt" "%LISTDIR%\" >> "%LOG%" 2>&1
if not exist "%LISTDIR%\list-general.txt" copy /y "%PSRC%lists\list-general.txt" "%LISTDIR%\" >> "%LOG%" 2>&1
for %%F in (dnscrypt-proxy.toml strategy.cmd autotune.bat start.bat stop.bat status.bat uninstall.bat blockcheck.bat dns.bat) do copy /y "%PSRC%%%F" "%DEST%\" >> "%LOG%" 2>&1
if not exist "%LISTDIR%\list-general.txt" goto :nolist
if not exist "%LISTDIR%\strategies.txt" goto :nolist
if not exist "%DEST%\autotune.bat" goto :nolist
if not exist "%DEST%\dnscrypt-proxy.toml" goto :nolist
echo       OK

rem --- [3/7] zapret binaries ---
echo [3/7] zapret engine ...
if exist "%WINWS%" goto :bin_ok
echo       downloading zapret Windows bundle (~20 MB) ...
call :fetch "https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip"
if errorlevel 1 goto :fail
xcopy "%DL%\zapret-win-bundle-master\*" "%BIN%\" /e /i /y >> "%LOG%" 2>&1
:bin_ok
if not exist "%WINWS%" goto :nowinws
rmdir /s /q "%DL%" >nul 2>&1
echo       OK

rem --- [3b] dnscrypt-proxy (local encrypted DNS). Pinned release; CPU auto-detected ---
echo       encrypted DNS resolver ...
if exist "%DCX%" goto :dc_ok
set "DCARCH=win64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "DCARCH=winarm"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "DCARCH=winarm"
call :fetch "https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/%DCVER%/dnscrypt-proxy-%DCARCH%-%DCVER%.zip"
if errorlevel 1 goto :fail
if not exist "%BIN%\dnscrypt" mkdir "%BIN%\dnscrypt"
for /d %%D in ("%DL%\win*") do xcopy "%%D\*" "%BIN%\dnscrypt\" /e /i /y >> "%LOG%" 2>&1
rmdir /s /q "%DL%" >nul 2>&1
:dc_ok
if not exist "%DCX%" goto :nodc
echo       OK

rem --- [4/7] Encrypted DNS (defeats ISP DNS hijacking; must precede tests) ---
echo [4/7] Encrypted DNS ...
call "%DEST%\dns.bat" set
if errorlevel 1 echo       continuing without encrypted DNS - Roblox may still fail

rem --- [5/7] Auto-detect the bypass method that works on this network ---
echo [5/7] Detecting the right bypass method for your network ...
set "TUNED=1"
call "%DEST%\autotune.bat" /install
if errorlevel 1 set "TUNED=0"
if "%TUNED%"=="0" echo       continuing with the default method

rem --- [6/7] Service (auto-start on boot). Space-free path -> no inner quotes ---
echo [6/7] Windows service ...
call "%DEST%\strategy.cmd"
echo ARGS=%SLX_ARGS% >> "%LOG%"
sc stop %SVC% >nul 2>&1
sc delete %SVC% >nul 2>&1
sc create %SVC% binPath= "%WINWS% %SLX_ARGS%" start= auto DisplayName= "SLXDPI (DPI bypass)" >> "%LOG%" 2>&1
if errorlevel 1 goto :nosvc
sc description %SVC% "DPI bypass for Turkey: Discord, Roblox and blocked sites. Banking/payments are NOT affected." >nul
echo       OK

rem --- [7/7] Start ---
echo [7/7] Starting ...
sc start %SVC% >> "%LOG%" 2>&1
timeout /t 3 /nobreak >nul
sc query %SVC% | find "RUNNING" >nul
if errorlevel 1 goto :nostart
echo       OK

echo.
if "%TUNED%"=="0" goto :done_untuned
echo === INSTALL COMPLETE ===
echo  - Service: %SVC% (starts automatically on Windows boot)
echo  - On/Off: start.bat / stop.bat   Diagnose: status.bat   Remove: uninstall.bat
echo  - Stopped working later? run autotune.bat (re-detects the method)
echo.
echo  TEST: open Roblox (images should load), join a Discord voice channel.
echo        Banking/payments (3-D Secure) are NOT affected - not in the list.
echo  NOTE: do not run GoodbyeDPI at the same time.
echo.
pause
exit /b 0

:done_untuned
echo === INSTALLED, BUT NO WORKING BYPASS METHOD WAS FOUND ===
echo  The service runs with the default method, which may not work here.
echo  Run status.bat and send its output, or run autotune.bat to retry.
echo.
pause
exit /b 1

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

:dest_unwritable
echo [ERROR] Cannot write into %DEST%. What is there right now:
dir C:\ /a | find /i "slxdpi"
echo         Delete or rename C:\slxdpi in File Explorer, then run this again.
echo         If it keeps failing, send this screen.
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

:nodc
echo [ERROR] dnscrypt-proxy.exe missing after extract: %DCX%
echo         Antivirus may have removed it (Protection history). Details: %LOG%
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
