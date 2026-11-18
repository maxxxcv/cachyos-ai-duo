#!/usr/bin/env bash
# First-boot setup, run by ai-duo-firstboot.service as root on the INSTALLED system (never in the live USB).
# No typing needed. Idempotent: every step leaves a marker, so a reboot or a failure just resumes.
# Needs internet (packages and models are downloaded now, not stored on the stick).
# AI_DUO_TEST=1 = running inside a chroot for testing: no daemons are started, no models are pulled.
set -u
LIB=/usr/local/lib/ai-duo
STATE=/var/lib/ai-duo
LOG=/var/log/ai-duo-firstboot.log
mkdir -p "$STATE"
exec >>"$LOG" 2>&1
TEST="${AI_DUO_TEST:-}"

if [ -d /run/archiso ]; then echo "live session: nothing to do"; exit 0; fi
[ -e "$STATE/done" ] && exit 0
echo "=== first boot setup $(date) ==="

step() {  # step <name> <function>
  local name="$1"; shift
  [ -e "$STATE/$name.done" ] && return 0
  echo "== $name"
  if "$@"; then touch "$STATE/$name.done"; else echo "!! step failed: $name (will retry on next boot)"; FAILED=1; fi
}
FAILED=0

wait_network() {
  [ -n "$TEST" ] && return 0
  for _ in $(seq 1 90); do
    if getent hosts archlinux.org >/dev/null 2>&1; then return 0; fi
    sleep 5
  done
  echo "no internet after 7 minutes"; return 1
}

pick_role() {
  # i7-8700 (no AVX-512) = computer A. 11th-gen i7 (AVX-512) = computer B.
  local role=a
  grep -q avx512f /proc/cpuinfo 2>/dev/null && role=b
  echo "$role" > "$STATE/role"
  echo "pc-$role" > /etc/hostname
  [ -z "$TEST" ] && hostname "pc-$role"
  return 0
}

packages() {
  # a freshly installed system may have an empty keyring; create it, refresh the keyrings, then upgrade fully
  if [ ! -s /etc/pacman.d/gnupg/pubring.kbx ] && [ ! -s /etc/pacman.d/gnupg/pubring.gpg ]; then
    pacman-key --init || return 1
    pacman-key --populate archlinux cachyos || return 1
  fi
  pacman -Sy --noconfirm archlinux-keyring cachyos-keyring || return 1
  pacman -Su --noconfirm || return 1
  pacman -S --needed --noconfirm \
    avahi nss-mdns iperf3 nftables openssh \
    vulkan-intel intel-compute-runtime openvino openvino-intel-gpu-plugin intel-media-driver libva-utils \
    ollama opencode nodejs-lts-krypton npm git firefox \
    noto-fonts noto-fonts-emoji inter-font ttf-jetbrains-mono power-profiles-daemon kvantum
}

system_config() {
  local role; role=$(cat "$STATE/role")
  # themes (system-wide, so every user gets them)
  install -d /usr/share/color-schemes /usr/share/Kvantum
  cp "$LIB"/theme/kde/*.colors /usr/share/color-schemes/
  cp -r "$LIB"/theme/Kvantum/* /usr/share/Kvantum/
  # name discovery between the two computers
  grep -q mdns_minimal /etc/nsswitch.conf || \
    sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
  # wired network: DHCP if a router answers, otherwise IPv6 link-local (found through avahi)
  install -d -m 700 /etc/NetworkManager/system-connections
  cat > /etc/NetworkManager/system-connections/pair-wired.nmconnection <<'NM'
[connection]
id=pair-wired
type=ethernet
autoconnect=true

[ipv4]
method=auto
may-fail=true

[ipv6]
method=auto
addr-gen-mode=eui64
NM
  chmod 600 /etc/NetworkManager/system-connections/pair-wired.nmconnection
  # firewall: pair ports only on wired links
  install -d /etc/pair
  cat > /etc/pair/pair.nft <<'NFT'
table inet pair
delete table inet pair
table inet pair {
  chain input {
    type filter hook input priority -10; policy accept;
    iifname != "lo" iifname != "en*" tcp dport { 50052, 5201, 11434 } drop
  }
}
NFT
  cat > /etc/systemd/system/pair-firewall.service <<'UNIT'
[Unit]
Description=Pair ports only on wired links
After=network-pre.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nft -f /etc/pair/pair.nft
[Install]
WantedBy=multi-user.target
UNIT
  # browser: no telemetry, hardware video decode, uBlock Origin
  install -d /etc/firefox/policies
  cp "$LIB/desktop/firefox-policies.json" /etc/firefox/policies/policies.json
  echo 'vm.swappiness=100' > /etc/sysctl.d/99-ai-desktop.conf
  # Ollama: local only, limited so the desktop never freezes
  local ram_gb mem_max
  ram_gb=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
  mem_max=$(( ram_gb * 70 / 100 ))
  install -d /etc/systemd/system/ollama.service.d
  cat > /etc/systemd/system/ollama.service.d/local.conf <<UNIT
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_CONTEXT_LENGTH=16384"
MemoryMax=${mem_max}G
Nice=5
UNIT
  if [ "$role" = b ]; then
    # computer B serves whole models to computer A over the cable (firewall limits it to wired links)
    cat > /etc/systemd/system/ollama.service.d/remote.conf <<'UNIT'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
UNIT
  fi
  install -m 755 "$LIB/ai/aimodel" /usr/local/bin/aimodel
  systemctl enable avahi-daemon.service ollama.service power-profiles-daemon.service pair-firewall.service
  if [ -z "$TEST" ]; then
    systemctl daemon-reload
    systemctl restart avahi-daemon.service ollama.service power-profiles-daemon.service pair-firewall.service NetworkManager.service
    sysctl --system >/dev/null
  fi
  return 0
}

assistant_install() {
  # system-wide (/usr/local/bin) so every shell finds it; per the OpenClaw docs: npm, with install scripts allowed only for openclaw
  command -v openclaw >/dev/null && return 0
  npm install -g --prefix /usr/local openclaw@latest --allow-scripts=openclaw || npm install -g --prefix /usr/local openclaw@latest
  command -v openclaw >/dev/null
}

user_setup() {
  local u rc=0
  for u in $(awk -F: '$3>=1000 && $3<60000 && $1 != "liveuser" && $7 !~ /nologin|false/ {print $1}' /etc/passwd); do
    echo "-- user $u"
    runuser -l "$u" -c "AI_DUO_TEST='$TEST' bash $LIB/firstboot/user-setup.sh" || rc=1
  done
  return $rc
}

models() {
  [ -n "$TEST" ] && return 0
  for _ in $(seq 1 30); do curl -sf http://127.0.0.1:11434/api/tags >/dev/null && break; sleep 2; done
  local rc=0 m
  while read -r m; do
    echo "pulling $m"; ollama pull "$m" || rc=1
  done < <(grep -vE '^\s*(#|$)' "$LIB/ai/models.conf")
  return $rc
}

select_model() {
  [ -n "$TEST" ] && return 0
  local u
  for u in $(awk -F: '$3>=1000 && $3<60000 && $1 != "liveuser" && $7 !~ /nologin|false/ {print $1}' /etc/passwd); do
    runuser -l "$u" -c 'aimodel use chat' || true
  done
  return 0
}

step network wait_network
[ -e "$STATE/network.done" ] || { echo "waiting for internet; will retry"; exit 1; }
step role pick_role
step packages packages
step config system_config
step assistant assistant_install
step users user_setup
step models models
step select select_model

if [ "$FAILED" = 0 ]; then
  touch "$STATE/done"
  echo "=== setup finished ==="
else
  echo "=== setup incomplete; will retry on next boot ==="
  exit 1
fi
