@echo off
setlocal
title SLXDPI
rem ============================================================
rem  SLXDPI - DPI bypass for Turkey (Discord, Roblox).
rem  The ONLY file you run. Right-click > Run as administrator.
rem
rem  Installs to C:\slxdpi:
rem    slxdpi.cmd   this file
rem    config\      hostlist.txt, strategies.txt, dnscrypt-proxy.toml,
rem                 tuned.txt (auto-detected method), version.txt
rem    bin\         zapret (winws) + dnscrypt-proxy, downloaded
rem    slxdpi.log   install log
rem
rem  Flat goto/call flow on purpose: no logic inside ( ) blocks,
rem  so no batch variable-expansion surprises.
rem ============================================================

set "VER=1.1"
set "DEST=C:\slxdpi"
set "CFG=%DEST%\config"
set "BIN=%DEST%\bin"
set "WINWS=%BIN%\zapret-winws\winws.exe"
set "DCDIR=%BIN%\dnscrypt"
set "DCX=%DCDIR%\dnscrypt-proxy.exe"
set "DCVER=2.1.18"
set "DL=%DEST%\_dl"
set "LOG=%DEST%\slxdpi.log"
set "SVC=SLXDPI"
set "SRC=%~dp0"
set "REPO=https://github.com/thesleax/slxdpi/archive/refs/heads/main.zip"

net session >nul 2>&1
if errorlevel 1 goto :notadmin

rem ============================================================
rem  MENU
rem ============================================================
:menu
call :state
cls
echo.
echo   SLXDPI %VER%   DPI bypass for Turkey  -  Discord, Roblox  -  payments untouched
echo   ------------------------------------------------------------------------------
if "%INST%"=="0" echo   Service : NOT INSTALLED
if "%INST%%RUN%"=="11" echo   Service : RUNNING
if "%INST%%RUN%"=="10" echo   Service : STOPPED
if "%DNS%"=="1" (echo   DNS     : ENCRYPTED) else (echo   DNS     : normal)
if exist "%CFG%\tuned.txt" (echo   Method  : auto-detected for this network) else (echo   Method  : default)
echo   ------------------------------------------------------------------------------
echo.
if "%INST%"=="0" echo   [1] Install
if "%INST%%OLD%"=="11" echo   [1] Update to %VER%          (installed: %IVER%)
if "%INST%%OLD%"=="10" echo   [1] Install               - already installed
if "%INST%%RUN%"=="10" (echo   [2] Start) else (echo   [2] Start                 - not available)
if "%RUN%"=="1" (echo   [3] Stop) else (echo   [3] Stop                  - not running)
if "%INST%"=="1" (echo   [4] Re-detect method) else (echo   [4] Re-detect method      - install first)
echo   [5] Diagnostics
if "%INST%"=="1" (echo   [6] Uninstall) else (echo   [6] Uninstall             - not installed)
if exist "%BIN%\blockcheck\blockcheck.cmd" (echo   [7] Advanced: zapret blockcheck) else (echo   [7] Advanced: zapret blockcheck - install first)
echo   [0] Exit
echo.
choice /c 12345670 /n /m "  Select: "
set "SEL=%errorlevel%"
if "%SEL%"=="8" exit /b 0
if "%SEL%"=="1" call :act_install
if "%SEL%"=="2" call :act_start
if "%SEL%"=="3" call :act_stop
if "%SEL%"=="4" call :act_tune
if "%SEL%"=="5" call :act_status
if "%SEL%"=="6" call :act_uninstall
if "%SEL%"=="7" call :act_blockcheck
goto :menu

:state
set "INST=0"
set "RUN=0"
set "DNS=0"
set "OLD=0"
set "IVER="
sc query %SVC% >nul 2>&1 && set "INST=1"
sc query %SVC% 2>nul | find "RUNNING" >nul && set "RUN=1"
sc query dnscrypt-proxy 2>nul | find "RUNNING" >nul && set "DNS=1"
if exist "%CFG%\version.txt" set /p IVER=<"%CFG%\version.txt"
if not defined IVER set "IVER=old"
if "%INST%"=="1" if not "%IVER%"=="%VER%" set "OLD=1"
exit /b 0

rem ---- menu actions: refuse what makes no sense, else run + pause ----
:act_install
if "%INST%%OLD%"=="10" goto :say_installed
call :install
echo.
pause
exit /b 0

:act_start
if "%INST%"=="0" goto :say_notinstalled
if "%RUN%"=="1" goto :say_running
echo.
call :svc_start
if not errorlevel 1 echo       [OK] SLXDPI is running.
echo.
pause
exit /b 0

:act_stop
if "%RUN%"=="0" goto :say_notrunning
sc stop %SVC% >nul 2>&1
call :msg "[OK] SLXDPI stopped. Encrypted DNS stays on."
exit /b 0

:act_tune
if "%INST%"=="0" goto :say_notinstalled
echo.
call :tune
echo.
pause
exit /b 0

:act_status
call :status
echo.
pause
exit /b 0

:act_uninstall
if "%INST%"=="0" goto :say_notinstalled
echo.
choice /c YN /n /m "  Remove SLXDPI and restore normal DNS? [Y/N] "
if errorlevel 2 exit /b 0
call :uninstall
echo.
pause
exit /b 0

:act_blockcheck
if not exist "%BIN%\blockcheck\blockcheck.cmd" goto :say_notinstalled
echo.
echo   Test domains to enter: discord.com , tr.rbxcdn.com
echo   Put a working "--dpi-desync=..." line into %CFG%\tuned.txt, then Stop + Start.
echo.
call "%BIN%\blockcheck\blockcheck.cmd"
pause
exit /b 0

:say_installed
call :msg "Already installed and up to date. Uninstall first for a clean reinstall."
exit /b 0
:say_notinstalled
call :msg "SLXDPI is not installed yet. Choose [1] Install."
exit /b 0
:say_running
call :msg "Already running."
exit /b 0
:say_notrunning
call :msg "Already stopped."
exit /b 0

:msg
echo.
echo   %~1
timeout /t 3 /nobreak >nul
exit /b 0

rem ============================================================
rem  INSTALL / UPDATE
rem ============================================================
:install
echo.
echo === Installing SLXDPI %VER% -^> %DEST% ===
call :ensure_dest
if errorlevel 1 exit /b 1
echo SLXDPI %VER% install %DATE% %TIME% > "%LOG%"
echo SRC=%SRC% >> "%LOG%"

rem [1] zapret/WinDivert is an antivirus FALSE POSITIVE; without an exclusion
rem     Defender deletes it mid-install. Add-MpPreference fails silently when
rem     Tamper Protection is ON, so verify it actually stuck.
echo [1/7] Windows Defender exclusion for %DEST% ...
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath '%DEST%' -ErrorAction Stop } catch {}"
powershell -NoProfile -Command "try { if ((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains '%DEST%'){exit 0} else {exit 3} } catch { exit 0 }"
if errorlevel 3 goto :i_noexcl
echo       OK

echo [2/7] Project files ...
call :copy_project
if errorlevel 1 exit /b 1
echo       OK

echo [3/7] Engine (zapret + encrypted DNS resolver) ...
call :get_zapret
if errorlevel 1 exit /b 1
call :get_dnscrypt
if errorlevel 1 exit /b 1
echo       OK

rem [4] DNS first: the ISP hijacks plain DNS, and the method tests need real addresses
echo [4/7] Encrypted DNS ...
call :dns_set
if errorlevel 1 echo       continuing without encrypted DNS - Roblox may still fail

echo [5/7] Detecting the right bypass method for your network ...
set "TUNED=1"
call :tune install
if errorlevel 1 set "TUNED=0"
if "%TUNED%"=="0" echo       continuing with the default method

echo [6/7] Windows service ...
call :svc_create
if errorlevel 1 exit /b 1
echo       OK

echo [7/7] Starting ...
call :svc_start
if errorlevel 1 exit /b 1
echo       OK
> "%CFG%\version.txt" echo %VER%

echo.
if "%TUNED%"=="0" goto :i_untuned
echo === INSTALL COMPLETE ===
echo  Open Roblox (images should load) and join a Discord voice channel.
echo  Banking / 3-D Secure payments are not affected. Do not run GoodbyeDPI too.
exit /b 0

:i_untuned
echo === INSTALLED, BUT NO WORKING BYPASS METHOD WAS FOUND ===
echo  The service runs with the default method, which may not work here.
echo  Run [5] Diagnostics and send the output, or [4] Re-detect to retry.
exit /b 1

:i_noexcl
echo.
echo [!] Could not add the Defender exclusion automatically
echo     ("Tamper Protection" is ON). Add it by hand once:
echo       Windows Security ^> Virus ^& threat protection ^> Manage settings
echo       ^> Exclusions ^> Add an exclusion ^> Folder ^> %DEST%
echo     Turkish: Windows Guvenligi ^> Virus ve tehdit korumasi ^>
echo     Ayarlari yonet ^> Dislamalar ^> Dislama ekle ^> Klasor ^> %DEST%
echo     Then choose Install again.
exit /b 1

rem ---- C:\slxdpi must be a real, writable folder (a same-named file or a
rem      broken link passes "if exist" but every write fails) ----
:ensure_dest
if exist "%DEST%\*" goto :ed_check
if not exist "%DEST%" goto :ed_make
echo [!] %DEST% exists but is not a normal folder:
dir C:\ /a | find /i "slxdpi"
set "OLDNAME=slxdpi.old-%RANDOM%"
echo     renaming it to C:\%OLDNAME% and creating a fresh folder ...
ren "%DEST%" "%OLDNAME%"
:ed_make
mkdir "%DEST%"
:ed_check
type nul > "%DEST%\.write-test" 2>nul
if not exist "%DEST%\.write-test" goto :ed_fail
del "%DEST%\.write-test" >nul 2>&1
exit /b 0
:ed_fail
echo [ERROR] Cannot write into %DEST%. What is there right now:
dir C:\ /a | find /i "slxdpi"
echo         Delete or rename C:\slxdpi in File Explorer, then try again.
exit /b 1

rem ---- config + this file into C:\slxdpi. From next to slxdpi.cmd, else from
rem      GitHub. Keeps the user's hostlist; migrates/cleans older layouts. ----
:copy_project
set "PSRC=%SRC%"
if exist "%SRC%config\strategies.txt" goto :cp_go
echo       config folder not next to slxdpi.cmd, fetching from GitHub ...
call :fetch "%REPO%"
if errorlevel 1 exit /b 1
set "PSRC=%DL%\slxdpi-main\"
:cp_go
echo copying from %PSRC% >> "%LOG%"
if not exist "%CFG%" mkdir "%CFG%"
copy /y "%PSRC%config\strategies.txt" "%CFG%\" >> "%LOG%" 2>&1
copy /y "%PSRC%config\dnscrypt-proxy.toml" "%CFG%\" >> "%LOG%" 2>&1
if not exist "%CFG%\hostlist.txt" if exist "%DEST%\lists\list-general.txt" copy /y "%DEST%\lists\list-general.txt" "%CFG%\hostlist.txt" >> "%LOG%" 2>&1
if not exist "%CFG%\hostlist.txt" copy /y "%PSRC%config\hostlist.txt" "%CFG%\" >> "%LOG%" 2>&1
if not exist "%CFG%\tuned.txt" if exist "%DEST%\tuned.txt" copy /y "%DEST%\tuned.txt" "%CFG%\tuned.txt" >> "%LOG%" 2>&1
if /i not "%PSRC%"=="%DEST%\" copy /y "%PSRC%slxdpi.cmd" "%DEST%\" >> "%LOG%" 2>&1
for %%F in (install.bat start.bat stop.bat status.bat uninstall.bat blockcheck.bat autotune.bat dns.bat strategy.cmd dnscrypt-proxy.toml tuned.txt install.log) do if exist "%DEST%\%%F" del /q "%DEST%\%%F" >nul 2>&1
if exist "%DEST%\lists" rmdir /s /q "%DEST%\lists" >nul 2>&1
rmdir /s /q "%DL%" >nul 2>&1
if not exist "%CFG%\hostlist.txt" goto :cp_fail
if not exist "%CFG%\strategies.txt" goto :cp_fail
if not exist "%CFG%\dnscrypt-proxy.toml" goto :cp_fail
exit /b 0
:cp_fail
echo [ERROR] Project files missing in %CFG%. Details: %LOG%
exit /b 1

:get_zapret
if exist "%WINWS%" exit /b 0
echo       downloading zapret (~20 MB) ...
call :fetch "https://github.com/bol-van/zapret-win-bundle/archive/refs/heads/master.zip"
if errorlevel 1 exit /b 1
xcopy "%DL%\zapret-win-bundle-master\*" "%BIN%\" /e /i /y >> "%LOG%" 2>&1
rmdir /s /q "%DL%" >nul 2>&1
if exist "%WINWS%" exit /b 0
echo [ERROR] winws.exe missing after extract: %WINWS%
echo         Antivirus probably removed it: Windows Security ^> Protection history.
exit /b 1

:get_dnscrypt
if exist "%DCX%" exit /b 0
set "DCARCH=win64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "DCARCH=winarm"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "DCARCH=winarm"
echo       downloading dnscrypt-proxy %DCVER% (%DCARCH%) ...
call :fetch "https://github.com/DNSCrypt/dnscrypt-proxy/releases/download/%DCVER%/dnscrypt-proxy-%DCARCH%-%DCVER%.zip"
if errorlevel 1 exit /b 1
if not exist "%DCDIR%" mkdir "%DCDIR%"
for /d %%D in ("%DL%\win*") do xcopy "%%D\*" "%DCDIR%\" /e /i /y >> "%LOG%" 2>&1
rmdir /s /q "%DL%" >nul 2>&1
if exist "%DCX%" exit /b 0
echo [ERROR] dnscrypt-proxy.exe missing after extract: %DCX%
echo         Antivirus may have removed it: Windows Security ^> Protection history.
exit /b 1

rem ---- :fetch <url> -> download + extract into %DL% (curl+tar, PowerShell fallback) ----
:fetch
rmdir /s /q "%DL%" >nul 2>&1
mkdir "%DL%"
echo fetch %~1 >> "%LOG%"
where curl >nul 2>&1 || goto :fetch_ps
where tar  >nul 2>&1 || goto :fetch_ps
curl -fSL --retry 2 --connect-timeout 20 -o "%DL%\pkg.zip" "%~1" 2>> "%LOG%"
if errorlevel 1 goto :fetch_err
rem tar may warn on odd entries; success is judged by the files we need
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
rem  ENCRYPTED DNS  (local dnscrypt-proxy on 127.0.0.1, DoH)
rem  Turkish ISPs hijack plain port-53 DNS even to 1.1.1.1. System DNS is
rem  switched ONLY after the local resolver has answered, so a failure
rem  never cuts the internet. Same on Windows 10 and 11.
rem ============================================================
:dns_set
if not exist "%DCX%" goto :ds_missing
copy /y "%CFG%\dnscrypt-proxy.toml" "%DCDIR%\dnscrypt-proxy.toml" >nul
pushd "%DCDIR%"
dnscrypt-proxy.exe -service stop >nul 2>&1
dnscrypt-proxy.exe -service uninstall >nul 2>&1
dnscrypt-proxy.exe -service install >nul 2>&1
dnscrypt-proxy.exe -service start >nul 2>&1
popd
set "TRIES=0"
:ds_wait
set /a TRIES+=1
powershell -NoProfile -Command "try { Resolve-DnsName clientsettingscdn.roblox.com -Server 127.0.0.1 -DnsOnly -QuickTimeout -ErrorAction Stop | Out-Null } catch { exit 1 }"
if not errorlevel 1 goto :ds_ok
if %TRIES% geq 10 goto :ds_fail
timeout /t 3 /nobreak >nul
goto :ds_wait
:ds_ok
powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('127.0.0.1','::1'); '      adapter: ' + $_.Name }"
ipconfig /flushdns >nul 2>&1
echo       [OK] encrypted DNS active (local DoH resolver on 127.0.0.1)
exit /b 0
:ds_fail
echo       [!] local encrypted resolver did not answer - system DNS left unchanged.
echo           DoH (HTTPS to 1.1.1.1 / 8.8.8.8 / 9.9.9.9) may be blocked on this network.
exit /b 1
:ds_missing
echo       [!] dnscrypt-proxy.exe missing in %DCDIR%
exit /b 1

:dns_restore
rem DNS back to automatic first, then stop the resolver (no outage window)
powershell -NoProfile -Command "Get-NetAdapter | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }"
if not exist "%DCX%" goto :dr_done
pushd "%DCDIR%"
dnscrypt-proxy.exe -service stop >nul 2>&1
dnscrypt-proxy.exe -service uninstall >nul 2>&1
popd
:dr_done
ipconfig /flushdns >nul 2>&1
echo       [OK] DNS restored to automatic (DHCP).
exit /b 0

rem ============================================================
rem  AUTO-DETECT  (:tune [install])
rem  Tries each line of config\strategies.txt with a real HTTPS probe to
rem  Roblox settings/CDN/site and Discord; keeps the first that works in
rem  config\tuned.txt. With "install" it leaves the service to the caller.
rem ============================================================
:tune
set "TMODE=%~1"
if not exist "%WINWS%" goto :t_noengine

rem GoodbyeDPI fights winws for the same traffic: stop it and keep its
rem service from returning at boot (prints the undo command)
powershell -NoProfile -Command "Get-CimInstance Win32_Service | Where-Object PathName -match 'goodbyedpi' | ForEach-Object { Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue; Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue; '      stopped + disabled GoodbyeDPI service: ' + $_.Name + '   (undo: sc config ' + $_.Name + ' start= auto)' }"
taskkill /f /im goodbyedpi.exe >nul 2>&1 && echo       closed running goodbyedpi.exe
timeout /t 2 /nobreak >nul
tasklist | find /i "goodbyedpi.exe" >nul
if not errorlevel 1 goto :t_gdpi

set "ISP="
for /f "delims=" %%I in ('curl -s --max-time 5 https://ipinfo.io/org 2^>nul') do set "ISP=%%I"
if defined ISP echo       network: %ISP%

rem only one winws may own the traffic during tests
sc stop %SVC% >nul 2>&1
taskkill /f /im winws.exe >nul 2>&1
timeout /t 2 /nobreak >nul

set "FOUND="
set "WIN="
set "N=0"
echo       testing bypass methods (up to ~3 min) ...
for /f "usebackq eol=# delims=" %%S in ("%CFG%\strategies.txt") do call :t_try "%%S"
if not defined FOUND goto :t_none
> "%CFG%\tuned.txt" echo %FOUND%
echo       [OK] method %WIN% works on this network - saved
if /i "%TMODE%"=="install" exit /b 0
call :svc_create
if errorlevel 1 exit /b 1
call :svc_start
if errorlevel 1 exit /b 1
echo       service updated and restarted
exit /b 0

:t_none
echo       [!] no method reached Roblox + Discord on this network.
echo           Run [5] Diagnostics and send the output, or try [7] blockcheck.
if /i "%TMODE%"=="install" exit /b 1
call :svc_start
exit /b 1

:t_try
if defined FOUND exit /b 0
set /a N+=1
echo         [%N%] %~1
start "slxdpi-test" /min "%WINWS%" --wf-tcp=443 --filter-tcp=443 --hostlist=%CFG%\hostlist.txt %~1
timeout /t 2 /nobreak >nul
call :t_probe
set "R=%errorlevel%"
taskkill /f /im winws.exe >nul 2>&1
timeout /t 1 /nobreak >nul
if "%R%"=="0" set "FOUND=%~1"
if "%R%"=="0" set "WIN=%N%"
exit /b 0

rem 0 = every endpoint answered over HTTPS (any HTTP status)
:t_probe
curl -s -o nul --ssl-no-revoke --max-time 6 https://clientsettingscdn.roblox.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://tr.rbxcdn.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://www.roblox.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://discord.com/ >nul 2>&1 || exit /b 1
exit /b 0

:t_noengine
echo       [!] engine missing - choose Install first.
exit /b 1
:t_gdpi
echo       [!] GoodbyeDPI is still running and could not be stopped automatically.
echo           Close it by hand, then choose Re-detect.
exit /b 1

rem ============================================================
rem  SERVICE
rem ============================================================
rem Builds SLX_ARGS: TCP 443 + hostlist with the detected method, QUIC for the
rem same sites, and Discord voice (only Discord/STUN packets on its ports, so
rem Roblox game UDP is not captured). Space-free paths -> no inner quotes.
:build_args
set "SLX_LIST=%CFG%\hostlist.txt"
set "SLX_DESYNC=--dpi-desync=fake,multisplit --dpi-desync-split-pos=1 --dpi-desync-fooling=md5sig"
if exist "%CFG%\tuned.txt" set /p SLX_DESYNC=<"%CFG%\tuned.txt"
set "SLX_ARGS=--wf-tcp=443 --wf-udp=443,19294-19344,50000-50100 --filter-tcp=443 --hostlist=%SLX_LIST% %SLX_DESYNC% --new --filter-udp=443 --hostlist=%SLX_LIST% --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6"
exit /b 0

:svc_create
call :build_args
echo ARGS=%SLX_ARGS% >> "%LOG%"
sc stop %SVC% >nul 2>&1
sc delete %SVC% >nul 2>&1
timeout /t 1 /nobreak >nul
sc create %SVC% binPath= "%WINWS% %SLX_ARGS%" start= auto DisplayName= "SLXDPI (DPI bypass)" >> "%LOG%" 2>&1
if errorlevel 1 goto :sc_fail
sc description %SVC% "DPI bypass for Turkey: Discord, Roblox and listed sites. Banking/payments are NOT affected." >nul
exit /b 0
:sc_fail
echo [ERROR] Could not create the Windows service. Details: %LOG%
exit /b 1

:svc_start
sc start %SVC% >> "%LOG%" 2>&1
timeout /t 3 /nobreak >nul
sc query %SVC% | find "RUNNING" >nul
if errorlevel 1 goto :ss_fail
exit /b 0
:ss_fail
echo [ERROR] Service did not start. Run [5] Diagnostics. Details: %LOG%
exit /b 1

rem ============================================================
rem  UNINSTALL  (service + DNS + WinDivert driver; files stay)
rem ============================================================
:uninstall
echo.
echo === Removing SLXDPI ===
sc stop %SVC% >nul 2>&1
sc delete %SVC% >nul 2>&1
call :dns_restore
sc stop windivert >nul 2>&1
sc delete windivert >nul 2>&1
echo       [OK] Service, DNS and driver removed. Files remain in %DEST%.
exit /b 0

rem ============================================================
rem  DIAGNOSTICS  (paste this output when asking for help)
rem ============================================================
:status
cls
echo.
echo === SLXDPI %VER% diagnostics ===
echo.
echo [install folder]
if exist "%DEST%\*" (echo   %DEST%: folder OK) else (echo   %DEST%: NOT a normal folder or missing)
echo   installed version: %IVER%
echo.
echo [service]
sc query %SVC% | find "STATE" || echo   SLXDPI service NOT installed
if exist "%WINWS%" (echo   winws.exe: present) else (echo   winws.exe: MISSING)
tasklist /fi "imagename eq winws.exe" | find /i "winws.exe" >nul && echo   winws process: running || echo   winws process: NOT running
sc query dnscrypt-proxy | find "RUNNING" >nul && echo   encrypted DNS resolver: running || echo   encrypted DNS resolver: NOT running
echo.
echo [network]
curl -s --max-time 5 -w "\n" https://ipinfo.io/org || echo   (could not detect)
if exist "%CFG%\tuned.txt" (echo   auto-detected method:& type "%CFG%\tuned.txt") else (echo   auto-detected method: none yet)
echo.
echo [conflicts]
tasklist | find /i "goodbyedpi" >nul && echo   WARNING: goodbyedpi.exe running || echo   goodbyedpi.exe: not running
echo.
echo [defender]
powershell -NoProfile -Command "try { if ((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains '%DEST%'){'  exclusion %DEST%: OK'} else {'  exclusion %DEST%: MISSING'} } catch {'  defender: not available'}"
echo.
echo [dns]
powershell -NoProfile -Command "Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses} | ForEach-Object { '  ' + $_.InterfaceAlias + ': ' + ($_.ServerAddresses -join ', ') }"
echo.
echo [dns check]  (system answer differs from real answer = ISP DNS tampering)
echo   system DNS says:
powershell -NoProfile -Command "try { '    ' + ((Resolve-DnsName clientsettingscdn.roblox.com -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress).IPAddress -join ', ') } catch { '    FAILED: ' + $_.Exception.Message }"
echo   real answer (encrypted DoH):
powershell -NoProfile -Command "try { $r = Invoke-RestMethod -TimeoutSec 8 -Headers @{accept='application/dns-json'} 'https://cloudflare-dns.com/dns-query?name=clientsettingscdn.roblox.com&type=A'; '    ' + (($r.Answer | Where-Object type -eq 1).data -join ', ') } catch { '    FAILED: ' + $_.Exception.Message }"
echo.
echo [reachability]  (HTTP 000 = blocked/unreachable)
for %%H in (www.roblox.com clientsettingscdn.roblox.com tr.rbxcdn.com discord.com gateway.discord.gg) do curl -s -o nul --ssl-no-revoke --max-time 8 -w "  %%H -> HTTP %%{http_code}\n" https://%%H/
exit /b 0

:notadmin
echo.
echo   Run this file as ADMINISTRATOR:
echo   right-click slxdpi.cmd ^> "Run as administrator"
echo.
pause
exit /b 1
