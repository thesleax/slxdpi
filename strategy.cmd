@echo off
rem ============================================================
rem  SLXDPI - zapret bypass strategy (tune per ISP)
rem ============================================================
rem  Holds the DPI-bypass parameters passed to winws.exe.
rem  The defaults work on most Turkish ISPs. If they don't,
rem  run blockcheck.bat and paste the parameters it finds here.
rem
rem  LISTDIR is set by install.bat to C:\slxdpi\lists.
rem ============================================================

rem --- Ports to capture (WinDivert global filter) ---
set "SLX_WF_TCP=443"
set "SLX_WF_UDP=443,50000-65535"

rem --- TCP 443: Roblox images (rbxcdn), Discord web, general sites ---
set "SLX_TCP=--filter-tcp=443 --hostlist=%LISTDIR%\list-general.txt --dpi-desync=fake,split2 --dpi-desync-split-pos=1 --dpi-desync-fooling=md5sig --dpi-desync-ttl=0"

rem --- UDP 443 QUIC: Discord and sites that use QUIC ---
set "SLX_QUIC=--filter-udp=443 --hostlist=%LISTDIR%\list-general.txt --dpi-desync=fake --dpi-desync-repeats=6"

rem --- UDP 50000-65535: Discord VOICE traffic (no hostname, port range) ---
rem  ponytail: touches ALL UDP in this range; banks don't use it, games do
rem  (and games are who we're helping). If it causes trouble, clear this line.
set "SLX_VOICE=--filter-udp=50000-65535 --dpi-desync=fake --dpi-desync-repeats=6"
