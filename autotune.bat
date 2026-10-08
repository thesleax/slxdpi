@echo off
setlocal
rem ============================================================
rem  SLXDPI - auto-detect a DPI-bypass method that works on THIS
rem  network. Tries each line of lists\strategies.txt with a real
rem  connection test to Roblox + Discord, keeps the first winner
rem  in tuned.txt, then applies it to the service (if installed).
rem  install.bat runs this automatically. Re-run any time.
rem ============================================================
net session >nul 2>&1
if errorlevel 1 goto :notadmin

set "DEST=C:\slxdpi"
set "WINWS=%DEST%\bin\zapret-winws\winws.exe"
set "LIST=%DEST%\lists\list-general.txt"
set "CANDS=%DEST%\lists\strategies.txt"
set "MODE=%~1"
set "FOUND="
set "N=0"

if not exist "%WINWS%" goto :nowinws

rem GoodbyeDPI fights winws for the same traffic. Stop it, and keep its
rem service (any service running goodbyedpi.exe) from coming back at boot.
powershell -NoProfile -Command "Get-CimInstance Win32_Service | Where-Object PathName -match 'goodbyedpi' | ForEach-Object { Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue; Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue; '      stopped + disabled GoodbyeDPI service: ' + $_.Name + '   (undo: sc config ' + $_.Name + ' start= auto)' }"
taskkill /f /im goodbyedpi.exe >nul 2>&1 && echo       closed running goodbyedpi.exe
timeout /t 2 /nobreak >nul
tasklist | find /i "goodbyedpi.exe" >nul
if not errorlevel 1 goto :gdpi

for /f "delims=" %%I in ('curl -s --max-time 5 https://ipinfo.io/org 2^>nul') do set "ISP=%%I"
if defined ISP echo       network: %ISP%

rem Only one winws may own the traffic during tests
sc stop SLXDPI >nul 2>&1
taskkill /f /im winws.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo       testing bypass methods (up to ~3 min) ...
for /f "usebackq eol=# delims=" %%S in ("%CANDS%") do call :try "%%S"
if not defined FOUND goto :none

> "%DEST%\tuned.txt" echo %FOUND%
echo       [OK] method %WIN% works on this network - saved
set "RC=0"
goto :apply

:none
echo       [!] no method reached Roblox + Discord on this network.
echo           Keeping the previous/default method. Next steps: run status.bat,
echo           try blockcheck.bat for a deeper search, and send both outputs.
set "RC=1"

:apply
if /i "%MODE%"=="/install" exit /b %RC%
sc query SLXDPI >nul 2>&1
if errorlevel 1 goto :done
call "%DEST%\strategy.cmd"
sc config SLXDPI binPath= "%WINWS% %SLX_ARGS%" >nul
sc start SLXDPI >nul 2>&1
echo       service updated and restarted
:done
pause
exit /b %RC%

rem ---- :try "<desync args>"  start winws with them, probe, stop ----
:try
if defined FOUND exit /b 0
set /a N+=1
echo         [%N%] %~1
start "slxdpi-test" /min "%WINWS%" --wf-tcp=443 --filter-tcp=443 --hostlist=%LIST% %~1
timeout /t 2 /nobreak >nul
call :probe
set "R=%errorlevel%"
taskkill /f /im winws.exe >nul 2>&1
timeout /t 1 /nobreak >nul
if "%R%"=="0" set "FOUND=%~1"
if "%R%"=="0" set "WIN=%N%"
exit /b 0

rem ---- :probe  0 = every endpoint answered over HTTPS (any HTTP status) ----
:probe
curl -s -o nul --ssl-no-revoke --max-time 6 https://clientsettingscdn.roblox.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://tr.rbxcdn.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://www.roblox.com/ >nul 2>&1 || exit /b 1
curl -s -o nul --ssl-no-revoke --max-time 6 https://discord.com/ >nul 2>&1 || exit /b 1
exit /b 0

:notadmin
echo Run as administrator.
pause
exit /b 1

:nowinws
echo [ERROR] winws.exe missing - run install.bat first.
if /i not "%MODE%"=="/install" pause
exit /b 1

:gdpi
echo [ERROR] GoodbyeDPI is still running and could not be stopped automatically.
echo         Close it by hand (and remove its service), then run autotune.bat.
if /i not "%MODE%"=="/install" pause
exit /b 1
