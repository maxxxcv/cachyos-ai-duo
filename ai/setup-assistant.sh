#!/usr/bin/env bash
# Personal assistant ("Jarvis") on top of OpenClaw, using the local Ollama models. Run after ai/setup-ai.sh.
#   bash ai/setup-assistant.sh
# Nothing is sent out: the model is local, the gateway stays on loopback (OpenClaw default), and email, calendar,
# browser control and voice are NOT enabled here. They are opt-in because of prompt-injection risk.
# Install method follows the OpenClaw docs (npm, not 'curl | bash'). Not yet tested on hardware.
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user (the script uses sudo)."; exit 1; }
# shellcheck source=/dev/null
. "$(dirname "$0")/../lib.sh"
require_installed_system
sync_pacman_once
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== 1/5 Node.js (OpenClaw needs Node 24.16+ or 26.1+) =="
# nodejs-lts-krypton (Node 24 LTS): the plain nodejs package was broken on 2026-11-18 (links an older simdjson)
sudo pacman -S --needed --noconfirm nodejs-lts-krypton npm
node -v

echo "== 2/5 install OpenClaw for this user (no root, no curl|bash) =="
mkdir -p "$HOME/.local/bin"
npm config set prefix "$HOME/.local"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH";; esac
grep -q '.local/bin' "$HOME/.profile" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
npm install -g openclaw@latest --allow-scripts=openclaw || npm install -g openclaw@latest
openclaw --version

echo "== 3/5 point OpenClaw at local Ollama (native API, no /v1) =="
mkdir -p "$HOME/.config/environment.d"
echo 'OLLAMA_API_KEY=ollama-local' > "$HOME/.config/environment.d/ai-duo.conf"
export OLLAMA_API_KEY=ollama-local
openclaw config set models.providers.ollama.apiKey OLLAMA_API_KEY
openclaw config set models.providers.ollama.baseUrl "http://127.0.0.1:11434"

echo "== 4/5 model switcher =="
install -m 755 "$HERE/aimodel" "$HOME/.local/bin/aimodel"
aimodel use chat || echo "Model not downloaded yet: run 'aimodel pull chat' then 'aimodel use chat'."

echo "== 5/5 startup service and security check =="
echo "Next, run once (it asks you questions): openclaw onboard --install-daemon"
echo "Then check: openclaw security audit"
echo
echo "Telegram: create a bot with @BotFather, paste its token in the onboarding. Keep DM pairing ON so only you can talk to it."
echo "Email, calendar, browser control: leave off until you have read OpenClaw's tool-permission docs."
