#!/usr/bin/env bash
# Two-PC pairing setup for CachyOS. Run ONCE on each computer, as a normal user with sudo:
#   bash setup-pair.sh a     # on the i7-8700 computer (UHD 630)
#   bash setup-pair.sh b     # on the second computer (i7 11th gen)
# Idempotent: safe to run again. Not yet tested on real hardware.
set -euo pipefail
ROLE="${1:-}"
case "$ROLE" in a|b) ;; *) echo "usage: bash setup-pair.sh a|b"; exit 1;; esac
[ "$(id -u)" -ne 0 ] || { echo "Run as a normal user (the script uses sudo)."; exit 1; }
PEER=$([ "$ROLE" = a ] && echo b || echo a)

echo "== 1/6 packages =="
sudo pacman -S --needed --noconfirm avahi nss-mdns iperf3 openssh nftables \
  vulkan-intel intel-compute-runtime openvino openvino-intel-gpu-plugin ollama \
  git cmake base-devel vulkan-headers shaderc

echo "== 2/6 hostname: pc-$ROLE =="
sudo hostnamectl set-hostname "pc-$ROLE"

echo "== 3/6 name discovery (pc-$PEER.local) =="
sudo systemctl enable --now avahi-daemon.service
if ! grep -q 'mdns_minimal' /etc/nsswitch.conf; then
  sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
fi

echo "== 4/6 wired network: works with a router OR a direct cable =="
# DHCP if a router answers; otherwise IPv6 link-local (found through avahi). No manual IPs.
sudo nmcli connection delete pair-wired 2>/dev/null || true
sudo nmcli connection add type ethernet con-name pair-wired autoconnect yes \
  ipv4.method auto ipv4.may-fail yes ipv6.method auto ipv6.addr-gen-mode eui64 \
  802-3-ethernet.mtu 1500 >/dev/null

echo "== 5/6 firewall: pair ports only on the wired link =="
sudo mkdir -p /etc/pair
sudo tee /etc/pair/pair.nft >/dev/null <<NFT
table inet pair
delete table inet pair
table inet pair {
  chain input {
    type filter hook input priority -10; policy accept;
    # RPC worker (50052) and iperf3 (5201): wired interfaces only, never Wi-Fi.
    iifname != "lo" iifname != "en*" tcp dport { 50052, 5201, 11434 } drop
  }
}
NFT
sudo nft -f /etc/pair/pair.nft || echo "nft rule not loaded (check manually)"
sudo tee /etc/systemd/system/pair-firewall.service >/dev/null <<UNIT
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
sudo systemctl daemon-reload
sudo systemctl enable pair-firewall.service

echo "== 6/6 link test =="
bash "$(dirname "$0")/pair-status.sh" || true
echo "Done. Connect the other computer with the network cable, run this script there with the other letter, then: bash pair-status.sh"
