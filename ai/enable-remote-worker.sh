#!/usr/bin/env bash
# Run on the FASTER computer (B) so computer A can use its Ollama over the network cable:
#   bash ai/enable-remote-worker.sh
# Then on A:  OLLAMA_HOST=pc-b.local:11434 ollama run qwen3:8b
# Security: listens on all interfaces but the firewall (setup-pair.sh) drops port 11434 on non-wired links.
# Anyone on the same wired network can reach it, so use only a private network or a direct cable.
set -euo pipefail
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/remote.conf >/dev/null <<UNIT
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
UNIT
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
echo "Ollama on this computer now answers on the wired link (port 11434)."
