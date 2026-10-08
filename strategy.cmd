@echo off
rem ============================================================
rem  SLXDPI - zapret (winws) arguments. Builds SLX_ARGS.
rem  The TCP bypass method (SLX_DESYNC) is picked automatically by
rem  autotune.bat for YOUR network and saved to tuned.txt, which
rem  overrides the default below. Re-run autotune.bat to re-detect.
rem ============================================================
set "SLX_LIST=%~dp0lists\list-general.txt"

rem Default TCP method, used only until autotune has run
set "SLX_DESYNC=--dpi-desync=fake,multisplit --dpi-desync-split-pos=1 --dpi-desync-fooling=md5sig"
if exist "%~dp0tuned.txt" set /p SLX_DESYNC=<"%~dp0tuned.txt"

rem Profiles (separated by --new):
rem  1) TCP 443 + hostlist : Roblox (incl. rbxcdn images), Discord, listed sites
rem  2) UDP 443 + hostlist : QUIC for the same sites
rem  3) Discord voice      : only Discord/STUN packets on Discord's voice ports
set "SLX_ARGS=--wf-tcp=443 --wf-udp=443,19294-19344,50000-50100 --filter-tcp=443 --hostlist=%SLX_LIST% %SLX_DESYNC% --new --filter-udp=443 --hostlist=%SLX_LIST% --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6"
