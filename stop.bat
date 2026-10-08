@echo off
net session >nul 2>&1 || ( echo Run as administrator. & pause & exit /b 1 )
sc stop SLXDPI
echo [OK] SLXDPI stopped. (DNS unchanged; use uninstall.bat to remove everything)
pause
