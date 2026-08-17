#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# TCP-connect smoke test of the reverse proxy public ports after a VM swap.
# Only checks that nginx accepts connections; upstream cluster state is out
# of scope (the k8s workers may legitimately be down).
#
# Usage: public-check.sh <ip> <port> [port...]

IP=$1
shift

for port in "$@"; do
  ok=0
  for i in $(seq 1 20); do
    if nc -z -w 5 "$IP" "$port" 2>/dev/null; then
      echo "$IP:$port reachable"
      ok=1
      break
    fi
    echo "$IP:$port not reachable yet ($i/20)"
    sleep 15
  done
  if [ "$ok" -ne 1 ]; then
    echo "ERROR: $IP:$port still unreachable, cloud-init probably failed" >&2
    exit 1
  fi
done
