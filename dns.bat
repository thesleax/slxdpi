@echo off
rem ============================================================
rem  SLXDPI - switch DNS to encrypted DoH / restore it
rem  Usage:  dns.bat set   |   dns.bat restore
rem  Why: in Turkey, CDN names like rbxcdn are DNS-poisoned;
rem       encrypted DoH bypasses that (Roblox images load).
rem ============================================================

rem --- Find the active network adapter ---
for /f "delims=" %%I in ('powershell -NoProfile -Command "(Get-NetAdapter -Physical ^| Where-Object {$_.Status -eq 'Up'} ^| Select-Object -First 1 -ExpandProperty Name)"') do set "IF=%%I"
if "%IF%"=="" ( echo [DNS] No active adapter found, skipping. & exit /b 0 )

if /i "%~1"=="restore" goto restore

rem --- SET: Cloudflare DoH ---
netsh interface ipv4 set dnsservers name="%IF%" static 1.1.1.1 primary >nul 2>&1
netsh interface ipv4 add dnsservers name="%IF%" 1.0.0.1 index=2   >nul 2>&1
netsh interface ipv6 set dnsservers name="%IF%" static 2606:4700:4700::1111 primary >nul 2>&1
rem Windows 11: register DoH template for these resolvers (silently ignored on Win10)
netsh dns add encryption server=1.1.1.1 dohtemplate=https://cloudflare-dns.com/dns-query autoupgrade=yes udpfallback=no >nul 2>&1
netsh dns add encryption server=1.0.0.1 dohtemplate=https://cloudflare-dns.com/dns-query autoupgrade=yes udpfallback=no >nul 2>&1
netsh dns add encryption server=2606:4700:4700::1111 dohtemplate=https://cloudflare-dns.com/dns-query autoupgrade=yes udpfallback=no >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo [DNS] "%IF%" -> Cloudflare DoH (encrypted) enabled.
exit /b 0

:restore
netsh interface ipv4 set dnsservers name="%IF%" dhcp >nul 2>&1
netsh interface ipv6 set dnsservers name="%IF%" dhcp >nul 2>&1
ipconfig /flushdns >nul 2>&1
echo [DNS] "%IF%" -> restored to automatic (DHCP) DNS.
exit /b 0
