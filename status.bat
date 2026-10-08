@echo off
rem ============================================================
rem  SLXDPI - diagnostics. Paste this output when asking for help.
rem ============================================================
echo === SLXDPI diagnostics ===
echo.
echo [install folder]
if exist "C:\slxdpi\*" (echo   C:\slxdpi: folder OK) else (echo   C:\slxdpi: NOT a normal folder or missing & dir C:\ /a | find /i "slxdpi")
echo.
echo [service]
sc query SLXDPI | find "STATE" || echo   SLXDPI service NOT installed (install did not finish)
if exist "C:\slxdpi\bin\zapret-winws\winws.exe" (echo   winws.exe: present) else (echo   winws.exe: MISSING - antivirus deleted it or download failed)
tasklist /fi "imagename eq winws.exe" | find /i "winws.exe" >nul && echo   winws process: running || echo   winws process: NOT running
echo.
echo [network]
curl -s --max-time 5 -w "\n" https://ipinfo.io/org || echo   (could not detect)
if exist "C:\slxdpi\tuned.txt" (echo   auto-detected method:& type "C:\slxdpi\tuned.txt") else (echo   auto-detected method: none yet - run autotune.bat)
echo.
echo [conflicts]
sc query GoodbyeDPI >nul 2>&1 && echo   WARNING: GoodbyeDPI service installed - it conflicts, remove it || echo   GoodbyeDPI service: none
tasklist | find /i "goodbyedpi" >nul && echo   WARNING: goodbyedpi.exe running - close it || echo   goodbyedpi.exe: not running
echo.
echo [defender]
powershell -NoProfile -Command "try { if ((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains 'C:\slxdpi'){'  exclusion C:\slxdpi: OK'} else {'  exclusion C:\slxdpi: MISSING'} } catch {'  defender: not available'}"
echo.
echo [dns]
powershell -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | ForEach-Object { '  ' + $_.InterfaceAlias + ': ' + ($_.ServerAddresses -join ', ') }"
echo.
echo [reachability]  (HTTP 000 = blocked/unreachable)
for %%H in (www.roblox.com clientsettingscdn.roblox.com tr.rbxcdn.com discord.com gateway.discord.gg) do (
  curl -s -o nul --max-time 8 -w "  %%H -> HTTP %%{http_code}\n" https://%%H/
)
echo.
pause
