@echo off
net session >nul 2>&1 || ( echo Run as administrator. & pause & exit /b 1 )
sc start SLXDPI
sc query SLXDPI | find "RUNNING" >nul && echo [OK] SLXDPI is running. || echo [!] Could not start, see status.bat.
pause
