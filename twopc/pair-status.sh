#!/usr/bin/env bash
# Shows whether the two computers see each other and how fast the link is.
ME=$(hostname); PEER=$([ "$ME" = pc-a ] && echo pc-b || echo pc-a)
echo "This computer: $ME   Looking for: $PEER.local"
echo "CPU threads here: $(nproc)"
if ! getent hosts "$PEER.local" >/dev/null; then echo "Peer NOT found. Check the cable and that setup-pair.sh ran on both."; exit 1; fi
echo "Peer address: $(getent hosts "$PEER.local" | head -1)"
ping -c 3 -q "$PEER.local" | tail -2
echo "Speed test (start 'iperf3 -s' on the peer first):"
timeout 15 iperf3 -c "$PEER.local" -t 5 2>/dev/null | tail -4 || echo "iperf3 server not running on peer."
