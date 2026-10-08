#!/usr/bin/env bash
# SLXDPI list sanity check. zapret matches subdomains automatically, so this
# only checks that the root domains are present AND that no banking/payment
# domain leaked into the list (which would break 3-D Secure payments).
set -euo pipefail
LIST="$(dirname "$0")/../lists/list-general.txt"

must=(discord.com discord.media rbxcdn.com roblox.com)   # required
banned=(garanti isbank akbank yapikredi ziraat vakifbank denizbank papara iyzico 3dsecure visa mastercard troy bkm)  # would break payments, must NOT appear

fail=0
for d in "${must[@]}"; do
  grep -qxF "$d" "$LIST" || { echo "MISSING: $d"; fail=1; }
done
for b in "${banned[@]}"; do
  if grep -qi "$b" "$LIST"; then echo "DANGER: banking/payment domain in list: $b"; fail=1; fi
done

[ "$fail" = 0 ] && echo "OK: list is valid ($(grep -c . "$LIST") domains, no banks)" || { echo "FAILED"; exit 1; }
