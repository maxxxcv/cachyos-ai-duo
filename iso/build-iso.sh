#!/usr/bin/env bash
# Builds the custom CachyOS ISO: the official ISO plus first-boot automation, themes and the AI tooling hooks.
# Run as root on Linux (tested path: an Arch WSL distro). Needs: xorriso squashfs-tools rsync.
#   bash iso/build-iso.sh /path/original.iso /path/workdir /path/output.iso
# Does NOT upgrade any package inside the image: the kernel, modules and initramfs of the ISO stay consistent.
# Everything else (packages, models) is downloaded by the first-boot service on the installed system.
set -euo pipefail
ORIG="${1:?original iso}"; W="${2:?workdir}"; OUT="${3:?output iso}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }
mkdir -p "$W"

echo "== 1/6 unpack =="
if [ ! -d "$W/iso" ]; then
  mkdir -p "$W/iso"
  xorriso -osirrox on -indev "$ORIG" -extract / "$W/iso" >/dev/null 2>&1
  chmod -R u+w "$W/iso"
fi
rm -rf "$W/root"
unsquashfs -f -d "$W/root" "$W/iso/arch/x86_64/airootfs.sfs" >/dev/null
R="$W/root"

echo "== 2/6 overlay and first-boot files =="
# --no-perms: never copy directory modes from the source (it would make /usr and /etc world-writable)
rsync -rlt --no-perms --no-owner --no-group "$REPO/iso/overlay/" "$R/"
L="$R/usr/local/lib/ai-duo"
rm -rf "$L"
mkdir -p "$L/firstboot" "$L/ai" "$L/desktop" "$L/theme/kde" "$L/theme/gtk"
cp "$REPO"/iso/firstboot/*.sh "$L/firstboot/"
cp "$REPO/ai/aimodel" "$REPO/ai/profiles.conf" "$REPO/ai/models.conf" "$L/ai/"
cp "$REPO/desktop/firefox-policies.json" "$L/desktop/"
cp "$REPO"/kde/*.colors "$L/theme/kde/"
cp -r "$REPO/themes/Kvantum" "$L/theme/Kvantum"
cp -r "$REPO"/themes/gtk/* "$L/theme/gtk/"
# the whole project too, for reference and manual runs
mkdir -p "$R/opt/cachyos-ai-duo"
rsync -rlt --no-perms --no-owner --no-group --exclude .git --exclude video-gen --exclude iso/work "$REPO/" "$R/opt/cachyos-ai-duo/"
find "$L" "$R/opt/cachyos-ai-duo" -type f -exec chmod 644 {} +
chmod 755 "$L"/firstboot/*.sh "$L/ai/aimodel" "$R/usr/local/bin/ai-duo-progress"
chmod 644 "$R/etc/systemd/system/ai-duo-firstboot.service"
chmod 755 "$R/usr/share/applications" "$R/etc/xdg/autostart" 2>/dev/null || true
chmod 644 "$R/usr/share/applications/ai-duo-assistant-setup.desktop" "$R/etc/xdg/autostart/ai-duo-progress.desktop"
for d in usr etc usr/local usr/local/bin etc/systemd etc/systemd/system etc/xdg usr/share usr/share/applications opt; do
  [ "$(stat -c %a "$R/$d")" = 755 ] || { echo "FATAL: $d has mode $(stat -c %a "$R/$d"), expected 755"; exit 1; }
done
mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/ai-duo-firstboot.service "$R/etc/systemd/system/multi-user.target.wants/ai-duo-firstboot.service"

echo "== 3/6 dark color scheme as the default for new users =="
mkdir -p "$R/usr/share/color-schemes"
cp "$REPO"/kde/*.colors "$R/usr/share/color-schemes/"
for f in "$R/etc/skel/.config/kdeglobals" "$R/etc/skel/.config/kdedefaults/kdeglobals"; do
  [ -f "$f" ] && sed -i 's/^ColorScheme=.*/ColorScheme=WorkingTitleDark/' "$f"
done

echo "== 4/6 installer: always offline (so the image content is what gets installed) =="
S="$R/usr/share/calamares"
cp "$S/settings_offline.conf" "$S/settings.conf"
cp "$S/settings_offline.conf" "$S/settings_online.conf"
[ -d "$R/etc/calamares" ] && cp "$S/settings_offline.conf" "$R/etc/calamares/settings.conf"
cat > "$R/usr/local/bin/calamares-online.sh" <<'SH'
#!/bin/bash
# Replaced: this image installs offline from the USB (no internet needed for the OS itself).
sudo cp /usr/share/calamares/settings_offline.conf /etc/calamares/settings.conf
timedatectl set-ntp true 2>/dev/null || true
exec pkexec-wrapper calamares -D6 >> /home/liveuser/cachy-install.log 2>&1
SH
chmod 755 "$R/usr/local/bin/calamares-online.sh"

[ -z "${STOP_AFTER_ROOT:-}" ] || { echo "stopped after preparing $R"; exit 0; }

echo "== 5/6 squashfs (xz, a few minutes) =="
rm -f "$W/airootfs.sfs"
mksquashfs "$R" "$W/airootfs.sfs" -comp xz -b 1M -Xdict-size 100% -noappend -quiet
( cd "$W" && sha512sum airootfs.sfs > airootfs.sha512 )
ls -l "$W/airootfs.sfs"

echo "== 6/6 repack ISO (boot setup replayed from the original) =="
rm -f "$OUT"
xorriso -indev "$ORIG" -outdev "$OUT" -boot_image any replay \
  -map "$W/airootfs.sfs" /arch/x86_64/airootfs.sfs \
  -map "$W/airootfs.sha512" /arch/x86_64/airootfs.sha512 \
  -commit 2>&1 | tail -3
ls -l "$OUT"
( cd "$(dirname "$OUT")" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" && cat "$(basename "$OUT").sha256" )
