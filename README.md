# SLXDPI

A professional DPI-bypass system for Turkey. It restores access to services
blocked by ISP deep-packet inspection — **Discord** (including voice) and
**Roblox** (including images) — **without breaking card payments**.

Engine: **[zapret](https://github.com/bol-van/zapret) (winws)** · Windows service · local encrypted DNS ([dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy), DoH).
**Windows only.** Runs as Administrator.

## What it fixes

| Problem | Root cause | Fix |
|---|---|---|
| Roblox won't start / images don't load | ISPs hijack plain DNS (even to 1.1.1.1) and return fake addresses for Roblox, its settings server and its image CDN (`tr.rbxcdn.com`…); SNI is blocked too | Local encrypted DNS resolver (DoH) + `roblox.com`/`rbxcdn.com` in the bypass list |
| Discord connects but voice is broken/stuttering | Voice is UDP/QUIC; TCP-only tools (e.g. GoodbyeDPI) can't touch it | zapret handles QUIC (UDP 443) and voice ports (UDP 50000-65535) |
| Card payments / 3-D Secure rejected | A global bypass mode fragments all traffic and breaks bank 3DS pages | **Hostlist mode**: only listed sites are processed, banks are never touched |
| Some sites/games unreachable | SNI/DNS block | Add them to the list (see below) |

## Why not just GoodbyeDPI?

GoodbyeDPI is TCP-only, so it can't fix Discord voice or QUIC, and its global
mode is the usual reason card payments stop working. SLXDPI uses zapret in
**hostlist mode**, so the bypass applies only to the domains you list and
leaves banking, 3-D Secure, and everything else completely untouched.

## Install

1. Copy the `slxdpi` folder to a Windows machine.
2. Right-click `install.bat` → **Run as administrator**.
3. When it finishes: open Roblox (images should load), join a Discord voice channel.

The installer copies files to `C:\slxdpi`, downloads the zapret binaries from
the [official bundle](https://github.com/bol-van/zapret-win-bundle) and
[dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy), routes all DNS
through a local encrypted resolver, **auto-detects the bypass method that works on your
connection**, and installs a Windows service named `SLXDPI` (auto-starts on boot).

## Automatic network detection

You never need to know or pick your ISP. Bypass methods differ between ISPs
(and even between resellers on the same Türk Telekom infrastructure), so
`autotune.bat` doesn't guess from the ISP name. It **tests** each candidate in
`lists/strategies.txt` with a real HTTPS connection to Roblox (settings, image
CDN, site) and Discord, keeps the first one that works in `tuned.txt`, and
applies it to the service. The installer runs it automatically; run it again
any time things stop working (e.g. after your ISP changes its filtering).

## Daily use

| File | Action |
|---|---|
| `start.bat` / `stop.bat` | Turn on / off |
| `status.bat` | Full diagnostics: service, network, method, DNS, live reachability |
| `autotune.bat` | Re-detect the working bypass method for your connection |
| `uninstall.bat` | Remove the service, restore DNS |
| `blockcheck.bat` | Deep manual search (zapret's own tool) if autotune finds nothing |

## Encrypted DNS

Turkish ISPs intercept ordinary DNS (port 53), even when it is sent to
1.1.1.1 or 8.8.8.8, and answer with fake addresses for blocked sites. Then no
DPI trick can help, because the connection goes to the wrong server. SLXDPI
runs [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) as a local
service on `127.0.0.1` and sends every query over HTTPS (DoH) to Cloudflare,
Google or Quad9, which the ISP cannot tamper with. It works the same on
Windows 10 and 11. System DNS is switched only after the resolver has
answered, so a failure never cuts your internet; `uninstall.bat` restores
automatic DNS.

## Payment safety

SLXDPI runs in **hostlist mode**: winws only touches the domains in
`lists/list-general.txt`. Banks and 3-D Secure pages are **not** in that list,
so they are never affected. `tools/check-lists.sh` verifies no banking domain
ever slips into the list. **Never add a bank/payment domain to the list.**

## Adding sites

Edit `lists/list-general.txt` — one root domain per line (subdomains match
automatically, e.g. `rbxcdn.com` covers `tr.rbxcdn.com`). After editing,
run `stop.bat` then `start.bat`.

Note: most blocks in Turkey are **IP/court-order** based, which no DPI tool can
fix. Only SNI/DNS-level blocks (like Discord and Roblox) can be bypassed.

## Not working?

1. Run `status.bat` — it shows what's wrong (service, antivirus, DNS, which sites are reachable).
2. Run `autotune.bat` to re-detect the method.
3. Still nothing? Run `blockcheck.bat` (test `discord.com`, `tr.rbxcdn.com`), put the
   working `--dpi-desync=...` line into `C:\slxdpi\tuned.txt`, then `stop.bat` + `start.bat`.
4. Installer problems are logged to `C:\slxdpi\install.log`.

## Project layout

```
slxdpi/
  install.bat        installer (admin)
  autotune.bat       auto-detects the working bypass method
  start/stop/status/uninstall.bat
  blockcheck.bat     deep manual search (fallback)
  dns.bat            encrypted DNS on/off (called by installer)
  dnscrypt-proxy.toml  local DoH resolver config (Cloudflare/Google/Quad9)
  strategy.cmd       builds winws arguments (uses tuned.txt)
  lists/list-general.txt   bypassed domains (NO banks)
  lists/strategies.txt     autotune candidates, least invasive first
  tools/check-lists.sh     list validity check
  bin/               zapret binaries (downloaded by installer)
```

## Antivirus (false positive)

Windows Defender and other antivirus engines flag zapret/WinDivert as a trojan
(e.g. `Trojan:Win32/Suschil!rfn`). **This is a false positive** — WinDivert is a
legitimate open-source packet driver, and every DPI-bypass tool (including
GoodbyeDPI) triggers it. The installer adds a Defender exclusion for `C:\slxdpi`
automatically so the files aren't deleted mid-install.

If your antivirus still quarantines it, allow it manually:

- **Windows Defender:** Virus & threat protection → under the detection choose
  **Allow on device** (Turkish: *Cihazda izin ver*) → **Start actions**. Then add
  a folder exclusion: Settings → Exclusions → Add → Folder → `C:\slxdpi`.
- **Third-party AV:** add `C:\slxdpi` to its exclusions/whitelist.

Prefer not to trust it? Build is just scripts + the upstream
[zapret binaries](https://github.com/bol-van/zapret-win-bundle) — inspect both,
or scan `winws.exe` on VirusTotal.

## Disclaimer

SLXDPI is an anti-censorship tool for accessing lawful services that are
blocked at the network level. Use it on networks and for purposes you are
permitted to. It bundles no secrets and modifies only your own machine's
network settings; `uninstall.bat` reverses everything.

## Credits

Built on [zapret](https://github.com/bol-van/zapret) by bol-van.
Licensed under the MIT License.
