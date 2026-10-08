# SLXDPI

DPI bypass for Turkey. Restores **Discord** (including voice) and **Roblox**
(including images) on DPI-filtering ISPs, **without breaking card payments**.

One file to run. Windows 10 and 11. Requires Administrator.

Built on [zapret](https://github.com/bol-van/zapret) (winws) and
[dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy).

## Quick start

1. **Code → Download ZIP**, then extract it.
2. Right-click **`slxdpi.cmd`** → **Run as administrator**.
3. Press **1** (Install). When it says `INSTALL COMPLETE`, open Roblox.

That's it. SLXDPI runs as a Windows service and starts with Windows.

## The menu

```
  SLXDPI 1.1   DPI bypass for Turkey  -  Discord, Roblox  -  payments untouched
  ------------------------------------------------------------------------------
  Service : RUNNING
  DNS     : ENCRYPTED
  Method  : auto-detected for this network
  ------------------------------------------------------------------------------

  [1] Install               - already installed
  [2] Start                 - not available
  [3] Stop
  [4] Re-detect method
  [5] Diagnostics
  [6] Uninstall
  [7] Advanced: zapret blockcheck
  [0] Exit
```

The menu reads the real state every time and only runs actions that make
sense: it won't reinstall what is installed, start what is running, or stop
what is stopped. When a newer `slxdpi.cmd` is run, **[1]** becomes
**Update**. After installing, the menu is also at `C:\slxdpi\slxdpi.cmd`.

## What it fixes

| Problem | Root cause | Fix |
|---|---|---|
| Roblox won't start / images don't load | ISPs hijack plain DNS (even to 1.1.1.1) and return fake addresses for Roblox, its settings server and image CDN; SNI is filtered too | Local encrypted DNS + `roblox.com` / `rbxcdn.com` in the bypass list |
| Discord blocked, voice unreliable | SNI filtering; voice is UDP, which TCP-only tools can't handle | zapret handles TCP, QUIC and Discord voice packets |
| Card payments / 3-D Secure fail | Global bypass modes tamper with all traffic, including bank pages | **Hostlist mode**: only listed sites are touched, banks never |

## How it works

**Encrypted DNS.** Turkish ISPs intercept ordinary DNS (port 53), even when
it goes to 1.1.1.1 or 8.8.8.8, and answer with fake addresses for blocked
sites. No DPI trick helps when the connection goes to the wrong server.
SLXDPI runs dnscrypt-proxy as a local service on `127.0.0.1` and sends every
query over HTTPS (DoH) to Cloudflare, Google or Quad9. System DNS is switched
only after the resolver has answered, so a failure never cuts your internet.

**Automatic method detection.** Bypass methods differ between ISPs, and even
between resellers on the same Türk Telekom line, so SLXDPI doesn't guess from
your ISP's name. It **tests** each candidate in `config/strategies.txt` with a
real HTTPS connection to Roblox (settings, image CDN, site) and Discord, and
keeps the first one that works. If your ISP changes its filtering later, run
**[4] Re-detect method**.

**Payment safety.** winws only touches the domains in `config/hostlist.txt`.
Banks and 3-D Secure pages are not in that list, so they are never affected.
`tools/check-lists.sh` verifies that no banking domain slips into the list.
**Never add a bank or payment domain to it.**

## Adding sites

Edit `C:\slxdpi\config\hostlist.txt`: one root domain per line (subdomains
match automatically, `rbxcdn.com` covers `tr.rbxcdn.com`). Then **Stop** and
**Start** in the menu. Your list is kept when you update.

Most blocks in Turkey are **IP / court-order** based, which no DPI tool can
fix. Only SNI- and DNS-level blocks, like Discord and Roblox, can be bypassed.

## Not working?

1. **[5] Diagnostics** shows the service, antivirus, DNS and which sites are reachable.
2. **[4] Re-detect method**.
3. Still nothing: **[7] blockcheck** (test `discord.com`, `tr.rbxcdn.com`), put the
   working `--dpi-desync=...` line into `C:\slxdpi\config\tuned.txt`, then Stop + Start.
4. Install details are logged to `C:\slxdpi\slxdpi.log`.

Do not run GoodbyeDPI at the same time. SLXDPI stops and disables a running
GoodbyeDPI service automatically and prints the command to re-enable it.

## Antivirus (false positive)

Windows Defender and other antivirus engines flag zapret's WinDivert driver
as a trojan (e.g. `Trojan:Win32/Suschil!rfn`). **This is a false positive.**
WinDivert is a legitimate open-source packet driver, and every DPI-bypass
tool, GoodbyeDPI included, triggers it. The installer adds a Defender
exclusion for `C:\slxdpi`. If **Tamper Protection** blocks that, the installer
stops and shows how to add it by hand:

Windows Security → Virus & threat protection → Manage settings → Exclusions →
Add an exclusion → Folder → `C:\slxdpi`

You can inspect the scripts here and the upstream
[zapret binaries](https://github.com/bol-van/zapret-win-bundle), or scan
`winws.exe` on VirusTotal.

## Project layout

```
slxdpi/
  slxdpi.cmd               the only file you run (menu + all logic)
  config/
    hostlist.txt           bypassed domains (no banks)
    strategies.txt         auto-detection candidates, least invasive first
    dnscrypt-proxy.toml    local encrypted DNS (Cloudflare / Google / Quad9)
  tools/check-lists.sh     hostlist sanity check (development)
```

Installed to `C:\slxdpi`: `slxdpi.cmd`, `config\` (plus the detected method
in `tuned.txt`), `bin\` (downloaded zapret and dnscrypt-proxy) and
`slxdpi.log`.

## Uninstall

Menu → **[6] Uninstall** removes the service, the WinDivert driver and the
local DNS resolver, and restores automatic DNS. Files stay in `C:\slxdpi`;
delete the folder afterwards if you like.

## Disclaimer

SLXDPI is an anti-censorship tool for reaching lawful services that are
blocked at the network level. Use it where you are permitted to. It changes
only your own machine's network settings, and Uninstall reverses them.

## Credits

[zapret](https://github.com/bol-van/zapret) by bol-van ·
[dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) by the DNSCrypt project.
Licensed under the MIT License.
