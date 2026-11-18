#!/usr/bin/env bash
# Local AI agent stack for one computer: Ollama (models) + opencode (coding/chat agent).
# Run as a normal user:  bash ai/setup-ai.sh        (add --no-models to skip model downloads)
# Everything stays local: Ollama listens on 127.0.0.1 only. Not yet tested on real hardware.
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user (the script uses sudo)."; exit 1; }
# shellcheck source=/dev/null
. "$(dirname "$0")/../lib.sh"
require_installed_system
sync_pacman_once
HERE="$(cd "$(dirname "$0")" && pwd)"
RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
MEM_MAX=$(( RAM_GB * 70 / 100 ))

echo "== 1/4 packages =="
sudo pacman -S --needed --noconfirm ollama opencode

echo "== 2/4 Ollama service: local only, limited so the desktop never freezes =="
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/local.conf >/dev/null <<UNIT
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_CONTEXT_LENGTH=16384"
MemoryMax=${MEM_MAX}G
Nice=5
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service

echo "== 3/4 opencode: no sharing, no auto-update; local models are auto-discovered =="
mkdir -p "$HOME/.config/opencode"
cat > "$HOME/.config/opencode/opencode.json" <<JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "share": "disabled",
  "autoupdate": false,
  "model": "ollama/qwen2.5-coder:7b"
}
JSON

echo "== 4/4 models =="
if [ "${1:-}" = "--no-models" ]; then
  echo "skipped (run: grep -v '^#' $HERE/models.conf | xargs -n1 ollama pull)"
else
  grep -vE '^\s*(#|$)' "$HERE/models.conf" | while read -r m; do echo "pulling $m"; ollama pull "$m"; done
fi
echo "Done. Start the agent with: opencode"
