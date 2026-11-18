#!/usr/bin/env bash
# One command after installing CachyOS (KDE Plasma edition):
#   bash install.sh a     # on the i7-8700 computer
#   bash install.sh b     # on the second computer (also serves AI models to A)
# Steps: pairing and firewall, browser desktop, themes, local AI stack. Safe to re-run.
set -euo pipefail
ROLE="${1:-}"
case "$ROLE" in a|b) ;; *) echo "usage: bash install.sh a|b"; exit 1;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/twopc/setup-pair.sh" "$ROLE"
bash "$HERE/desktop/setup-desktop.sh"
bash "$HERE/desktop/install-themes.sh"
bash "$HERE/ai/setup-ai.sh"
if [ "$ROLE" = b ]; then bash "$HERE/ai/enable-remote-worker.sh"; fi
echo "All done. Reboot, then run: bash twopc/pair-status.sh"
