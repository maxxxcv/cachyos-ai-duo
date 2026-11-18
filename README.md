# cachyos-ai-duo

Working-title theme set and two-computer pairing scripts for a CachyOS (Arch) + KDE Plasma desktop.

- `design-brief.md`, `design-tokens.json/.css` - identity and design tokens (dark/light)
- `build_kde_scheme.py` -> `kde/` KDE color schemes
- `build_qt_gtk_themes.py` -> `themes/Kvantum`, `themes/gtk` (Kvantum themes derive from KvFlat, GPL-3)
- `build_login_boot_themes.py` -> `themes/sddm`, `themes/plymouth`
- `twopc/` - `setup-pair.sh a|b` and `pair-status.sh` for pairing two PCs over a network cable
- `write_usb.ps1` - writes the CachyOS ISO to a USB stick on Windows (guarded; run as Administrator)

Status: structure-checked only. Nothing here has been run on Linux or on real hardware yet.
Not included: the CachyOS ISO (get it from the official mirror and verify its sha256).

- `ai/` - local AI stack (Ollama + opencode agent), see `ai/README.md` for what is and is not built
- `tests/` and `.github/workflows/ci.yml` - structure/contrast tests, shellcheck and PowerShell syntax check on every push
- `install.sh a|b` - one command after installing CachyOS: pairing, browser desktop (`desktop/`), themes, AI stack
