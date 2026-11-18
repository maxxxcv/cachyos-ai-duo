#!/usr/bin/env bash
# Shared helpers, sourced by the setup scripts. Not run directly.

# Refuse to run inside the live USB session: nothing installed there survives a reboot.
require_installed_system() {
  if [ -d /run/archiso ] || [ "$(id -un)" = liveuser ]; then
    echo "STOP: this is the live USB session, not an installed system."
    echo "First run the installer (the 'Install CachyOS' icon), reboot into the installed system, then run this again."
    exit 1
  fi
}

# Sync package databases once (a fresh system has none). Uses a full upgrade, because Arch does not support partial upgrades.
sync_pacman_once() {
  if [ -z "${AI_DUO_SYNCED:-}" ]; then
    sudo pacman -Syu --noconfirm
    export AI_DUO_SYNCED=1
  fi
}
