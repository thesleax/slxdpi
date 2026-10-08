# SLXDPI

A professional DPI-bypass system for Turkey. It restores access to services
blocked by ISP deep-packet inspection — **Discord** (including voice) and
**Roblox** (including images) — **without breaking card payments**.

Engine: **[zapret](https://github.com/bol-van/zapret) (winws)** · Windows service · encrypted DNS (DoH).
**Windows only.** Runs as Administrator.

## What it fixes

| Problem | Root cause | Fix |
|---|---|---|
| Roblox opens but images don't load | Images come from a separate CDN (`tr.rbxcdn.com`, `t0–t7`, `c0–c7`) that is DNS-poisoned + SNI-blocked | `rbxcdn.com` in the bypass list + encrypted DoH DNS |
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
the [official bundle](https://github.com/bol-van/zapret-win-bundle), installs a
Windows service named `SLXDPI` (auto-starts on boot), and switches DNS to
Cloudflare DoH.

## Daily use

| File | Action |
|---|---|
| `start.bat` / `stop.bat` | Turn on / off |
| `status.bat` | Service + DNS status, `tr.rbxcdn.com` resolution test |
| `uninstall.bat` | Remove the service, restore DNS |
| `blockcheck.bat` | Find the right settings for your ISP if the defaults fail |

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

Bypass parameters differ per ISP (Superonline, Turkcell, TTNET…). If the
default strategy fails:

1. Run `blockcheck.bat` → when prompted, test `discord.com` and `tr.rbxcdn.com`.
2. Paste the resulting `--dpi-desync=...` line into the matching variable in `strategy.cmd`.
3. Run `stop.bat` then `start.bat`.

## Project layout

```
slxdpi/
  install.bat        installer (admin)
  start/stop/status/uninstall.bat
  blockcheck.bat     per-ISP setting finder
  dns.bat            DoH on/off (called by installer)
  strategy.cmd       DPI parameters (tune per ISP)
  lists/list-general.txt   bypassed domains (NO banks)
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
