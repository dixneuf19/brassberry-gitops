#!/usr/bin/env bash
# Edit the mangococo.fr forwarding map stored in Bitwarden (secret mangococo-email-forwards).
#   forwards.sh list
#   forwards.sh set contact@mangococo.fr a@example.org b@example.net
#   forwards.sh rm contact@mangococo.fr
set -euo pipefail
IFS=$'\n\t'

KEY=mangococo-email-forwards

usage() {
  sed -n '2,5p' "$0" >&2
  exit 1
}

id=$(bws secret list --output json | jq -r --arg k "$KEY" '.[] | select(.key == $k) | .id')
if [[ -z $id ]]; then
  echo "Bitwarden secret $KEY not found" >&2
  exit 1
fi
current=$(bws secret get "$id" --output json | jq -r .value)

case "${1:-}" in
  list)
    jq . <<<"$current"
    exit 0
    ;;
  set)
    [[ $# -ge 3 ]] || usage
    src=${2,,}
    [[ $src == *@mangococo.fr ]] || { echo "$src is not on mangococo.fr" >&2; exit 1; }
    shift 2
    dests=$(printf '%s\n' "$@" | jq -R 'ascii_downcase' | jq -sc 'unique')
    new=$(jq -c --arg s "$src" --argjson d "$dests" '.[$s] = $d' <<<"$current")
    ;;
  rm)
    [[ $# -eq 2 ]] || usage
    new=$(jq -c --arg s "${2,,}" 'del(.[$s])' <<<"$current")
    ;;
  *)
    usage
    ;;
esac

bws secret edit "$id" --value "$new" >/dev/null
jq . <<<"$new"
echo "Saved. Apply now: direnv reload && terraform -chdir=terraform/cloudflare apply (or wait for Burrito, up to ~1h)" >&2
