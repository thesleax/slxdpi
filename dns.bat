@echo off
setlocal
rem ============================================================
rem  SLXDPI - encrypted DNS via a local resolver (dnscrypt-proxy)
rem  Usage:  dns.bat set   |   dns.bat restore
rem  Why: Turkish ISPs hijack plain DNS (port 53) even to 1.1.1.1
rem       and return fake answers for Roblox/Discord. dnscrypt-proxy
rem       listens on 127.0.0.1 and sends queries over HTTPS (DoH),
rem       which the ISP can't tamper with. Same on Windows 10 and 11.
rem  Safety: system DNS is switched ONLY after the local resolver
rem          has answered, so a failure never cuts the internet.
rem ============================================================
set "DC=C:\slxdpi\bin\dnscrypt"
set "Q=clientsettingscdn.roblox.com"
if /i "%~1"=="restore" goto :restore

if not exist "%DC%\dnscrypt-proxy.exe" goto :missing
copy /y "%~dp0dnscrypt-proxy.toml" "%DC%\dnscrypt-proxy.toml" >nul

rem (Re)install the resolver service from its own folder, as upstream does
pushd "%DC%"
dnscrypt-proxy.exe -service stop >nul 2>&1
dnscrypt-proxy.exe -service uninstall >nul 2>&1
dnscrypt-proxy.exe -service install >nul 2>&1
dnscrypt-proxy.exe -service start >nul 2>&1
popd

rem Wait (up to ~30 s) until the local resolver really answers
set "TRIES=0"
:wait
set /a TRIES+=1
powershell -NoProfile -Command "try { Resolve-DnsName %Q% -Server 127.0.0.1 -DnsOnly -QuickTimeout -ErrorAction Stop | Out-Null } catch { exit 1 }"
if not errorlevel 1 goto :answered
if %TRIES% geq 10 goto :noanswer
timeout /t 3 /nobreak >nul
goto :wait

:answered
rem Point every active adapter (Wi-Fi, Ethernet, ...) at the local resolver
powershell -NoProfile -Command "Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('127.0.0.1','::1'); '      adapter: ' + $_.Name }"
ipconfig /flushdns >nul 2>&1
echo       [OK] encrypted DNS active (local DoH resolver on 127.0.0.1)
exit /b 0

:noanswer
echo       [!] local encrypted resolver did not answer - system DNS left unchanged.
echo           DoH (HTTPS to 1.1.1.1 / 8.8.8.8 / 9.9.9.9) may be blocked on this network.
exit /b 1

:missing
echo       [!] dnscrypt-proxy.exe missing in %DC% - run install.bat.
exit /b 1

:restore
rem DNS back to automatic first, then stop the resolver (no outage window)
powershell -NoProfile -Command "Get-NetAdapter | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }"
if not exist "%DC%\dnscrypt-proxy.exe" goto :restored
pushd "%DC%"
dnscrypt-proxy.exe -service stop >nul 2>&1
dnscrypt-proxy.exe -service uninstall >nul 2>&1
popd
:restored
ipconfig /flushdns >nul 2>&1
echo       [OK] DNS restored to automatic (DHCP).
exit /b 0
