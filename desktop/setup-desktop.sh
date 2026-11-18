#!/usr/bin/env bash
# Browsing-ready desktop: Firefox with hardware video decoding and no telemetry, Hebrew/RTL fonts,
# Intel media drivers, sane power and memory defaults. Run as a normal user. Not yet tested on hardware.
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user (the script uses sudo)."; exit 1; }
# shellcheck source=/dev/null
. "$(dirname "$0")/../lib.sh"
require_installed_system
sync_pacman_once
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== 1/4 packages =="
sudo pacman -S --needed --noconfirm firefox intel-media-driver libva-utils \
  noto-fonts noto-fonts-emoji inter-font ttf-jetbrains-mono power-profiles-daemon kvantum plymouth

echo "== 2/4 Firefox policy: no telemetry or studies, hardware video decode, uBlock Origin =="
sudo mkdir -p /etc/firefox/policies
sudo cp "$HERE/firefox-policies.json" /etc/firefox/policies/policies.json

echo "== 3/4 power and memory =="
sudo systemctl enable --now power-profiles-daemon.service || true
# zram swap is the CachyOS default; check it exists so the AI models do not push the system into disk swap.
if ! swapon --show | grep -q zram; then echo "NOTE: no zram swap found; install zram-generator and enable it."; fi
# Keep mmap'd model files from being evicted too eagerly.
echo 'vm.swappiness=100' | sudo tee /etc/sysctl.d/99-ai-desktop.conf >/dev/null
sudo sysctl --system >/dev/null

echo "== 4/4 check video decoding (VA-API) =="
vainfo 2>&1 | head -8 || echo "vainfo failed: check intel-media-driver and the GPU"
echo "Done. Open Firefox and check about:support (Media section) after your first video."
