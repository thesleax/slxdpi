@echo off
net session >nul 2>&1 || ( echo Run as administrator. & pause & exit /b 1 )
echo === Removing SLXDPI ===
sc stop SLXDPI >nul 2>&1
sc delete SLXDPI >nul 2>&1
call "%~dp0dns.bat" restore
if exist "%~dp0bin\zapret-winws\windivert_delete.cmd" call "%~dp0bin\zapret-winws\windivert_delete.cmd" >nul 2>&1
echo [OK] Service and DNS restored. Files remain in C:\slxdpi (delete manually if you want).
pause
