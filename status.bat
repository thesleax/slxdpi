@echo off
echo === SLXDPI service status ===
sc query SLXDPI | find "STATE"
echo.
echo === Active DNS ===
powershell -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | Select-Object InterfaceAlias,ServerAddresses | Format-Table -Auto"
echo === Does the Roblox image server resolve? ===
nslookup tr.rbxcdn.com
pause
