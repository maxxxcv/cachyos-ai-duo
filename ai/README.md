# Local AI on the two computers

| Capability | Status |
|---|---|
| Chat and Q&A (qwen3:8b via Ollama) | Prepared by `setup-ai.sh`. Not run yet. |
| Code agent (opencode + qwen2.5-coder:7b) | Prepared by `setup-ai.sh`. Not run yet. |
| Search over your files (nomic-embed-text) | Model is pulled; no indexer is built yet. |
| Use the second computer for LLMs | `enable-remote-worker.sh` (whole-model offload, not layer splitting). Not run yet. |
| Assistant (OpenClaw) | `setup-assistant.sh`: npm install, local Ollama, no email/calendar/browser/voice yet | Prepared, not run |
| Switch models | `aimodel list|use|pull|ask|status` and `profiles.conf` | Prepared, not run |
| Images | NOT built yet. Plan: stable-diffusion.cpp, same engine as video. |
| Video | In progress in `video-gen/` (baseline files downloaded, no clip generated yet). |

Honest limits: on CPU/iGPU an 7-8B model gives roughly a few tokens per second (not measured here). Video on this
hardware will be slow and low resolution; the measured numbers will come from `video-gen/`.
Splitting one LLM across both PCs over a network cable is possible (llama.cpp RPC) but is not set up; Ollama
itself cannot split a model, so B simply serves whole models for A.

Order: `bash twopc/setup-pair.sh a|b`, then `bash ai/setup-ai.sh`, then on B `bash ai/enable-remote-worker.sh`.
