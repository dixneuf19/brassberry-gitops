#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Post blue/green adoption of the reverse proxy on the tailnet:
# wait for the new device to join, delete the stale sibling records,
# rename the new device to the stable name (MagicDNS stays constant).
#
# Usage: tailnet-adopt.sh <current-os-hostname> <stable-name>
# Auth:  TAILSCALE_OAUTH_CLIENT_ID / TAILSCALE_OAUTH_CLIENT_SECRET
#        (OAuth client with auth_keys + devices:core write on tag:brassberry)

CURRENT_HOSTNAME=$1
TARGET_NAME=$2
API=https://api.tailscale.com/api/v2

TOKEN=$(curl -sf "$API/oauth/token" \
  -d "client_id=$TAILSCALE_OAUTH_CLIENT_ID" \
  -d "client_secret=$TAILSCALE_OAUTH_CLIENT_SECRET" | jq -r .access_token)

devices() {
  curl -sf -H "Authorization: Bearer $TOKEN" "$API/tailnet/-/devices"
}

CURRENT_ID=""
for i in $(seq 1 20); do
  DEVICES=$(devices)
  CURRENT_ID=$(echo "$DEVICES" | jq -r --arg h "$CURRENT_HOSTNAME" \
    '[.devices[] | select(.hostname == $h)][0].nodeId // empty')
  [ -n "$CURRENT_ID" ] && break
  echo "waiting for $CURRENT_HOSTNAME to join the tailnet ($i/20)"
  sleep 15
done
if [ -z "$CURRENT_ID" ]; then
  echo "ERROR: $CURRENT_HOSTNAME never joined the tailnet" >&2
  exit 1
fi

STALE_IDS=$(echo "$DEVICES" | jq -r --arg cur "$CURRENT_ID" --arg t "$TARGET_NAME" \
  '.devices[] | select(.nodeId != $cur)
   | select(.hostname | test("^" + $t + "(-[0-9a-f]{6})?$"))
   | .nodeId')

for id in $STALE_IDS; do
  echo "deleting stale device $id"
  curl -sf -X DELETE -H "Authorization: Bearer $TOKEN" "$API/device/$id"
done

echo "renaming $CURRENT_HOSTNAME ($CURRENT_ID) to $TARGET_NAME"
curl -sf -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TARGET_NAME\"}" \
  "$API/device/$CURRENT_ID/name"
echo "done"
