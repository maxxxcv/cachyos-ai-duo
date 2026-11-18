#!/usr/bin/env bash
# Per-user part of the first-boot setup. Runs as the normal user (via runuser -l), never as root.
set -u
LIB=/usr/local/lib/ai-duo
rc=0

mkdir -p "$HOME/.local/bin" "$HOME/.config/environment.d" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/Kvantum" "$HOME/.config/opencode"

# GTK colors
for v in gtk-3.0 gtk-4.0; do cp "$LIB/theme/gtk/WorkingTitleDark/$v/gtk.css" "$HOME/.config/$v/gtk.css"; done

# Qt widget style: Kvantum with the dark theme (Kvantum is installed by now)
printf '[General]\ntheme=WorkingTitleDark\n' > "$HOME/.config/Kvantum/kvantum.kvconfig"
if command -v kwriteconfig6 >/dev/null; then
  kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
  kwriteconfig6 --file kdeglobals --group General --key ColorScheme WorkingTitleDark
fi

# model switcher profiles (the aimodel command itself is in /usr/local/bin)
mkdir -p "$HOME/.config/ai-duo"
[ -f "$HOME/.config/ai-duo/profiles.conf" ] || cp "$LIB/ai/profiles.conf" "$HOME/.config/ai-duo/profiles.conf"

# code agent: no sharing, no auto-update
cat > "$HOME/.config/opencode/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "share": "disabled",
  "autoupdate": false,
  "model": "ollama/qwen2.5-coder:7b"
}
JSON

# assistant (OpenClaw, installed system-wide by the root part): point it at the local Ollama
echo 'OLLAMA_API_KEY=ollama-local' > "$HOME/.config/environment.d/ai-duo.conf"
export OLLAMA_API_KEY=ollama-local
if command -v openclaw >/dev/null; then
  openclaw config set models.providers.ollama.apiKey OLLAMA_API_KEY || rc=1
  openclaw config set models.providers.ollama.baseUrl "http://127.0.0.1:11434" || rc=1
else
  rc=1
fi
exit "$rc"
