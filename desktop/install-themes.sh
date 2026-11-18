#!/usr/bin/env bash
# Installs the dark theme set (KDE colors, Kvantum, GTK, SDDM login, Plymouth splash).
# Run as a normal user from the repo folder. Not yet tested on a real Plasma session.
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user (the script uses sudo)."; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== KDE color schemes =="
mkdir -p "$HOME/.local/share/color-schemes"
cp "$ROOT"/kde/*.colors "$HOME/.local/share/color-schemes/"

echo "== Kvantum =="
mkdir -p "$HOME/.config/Kvantum"
cp -r "$ROOT"/themes/Kvantum/* "$HOME/.config/Kvantum/"

echo "== GTK (dark) =="
for v in gtk-3.0 gtk-4.0; do
  mkdir -p "$HOME/.config/$v"
  cp "$ROOT/themes/gtk/WorkingTitleDark/$v/gtk.css" "$HOME/.config/$v/gtk.css"
done

echo "== SDDM login screen =="
sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
sudo cp -r "$ROOT/themes/sddm/WorkingTitle" /usr/share/sddm/themes/
printf '[Theme]\nCurrent=WorkingTitle\n' | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null

echo "== Plymouth boot splash (files only; see note) =="
sudo mkdir -p /usr/share/plymouth/themes
sudo cp -r "$ROOT/themes/plymouth/WorkingTitle" /usr/share/plymouth/themes/
sudo plymouth-set-default-theme WorkingTitle || echo "could not set the Plymouth theme"
echo "NOTE: Plymouth also needs its hook in the initramfs and 'splash' on the kernel command line."
echo "      That depends on the bootloader CachyOS installed; check the CachyOS wiki before rebuilding."

echo "== Apply to the current Plasma session =="
if command -v plasma-apply-colorscheme >/dev/null; then plasma-apply-colorscheme WorkingTitleDark || true; fi
if command -v kvantummanager >/dev/null; then kvantummanager --set WorkingTitleDark || true; fi
if command -v kwriteconfig6 >/dev/null; then kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum || true; fi
echo "Done. Log out and back in to see everything."
