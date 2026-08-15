#!/usr/bin/env bash
# One-time creation of the burrito-brassberry GitHub App from manifest.json,
# storing the returned credentials in Bitwarden Secrets Manager.
# See README.md for the full flow. Requires: gh, bws, jq, BWS_ACCESS_TOKEN.
set -euo pipefail
IFS=$'\n\t'

BW_PROJECT_ID="23028f7d-c2dd-4049-a1ef-b42300e91f30"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$(jq -c . "${SCRIPT_DIR}/manifest.json")"

# GitHub only accepts app manifests via a browser form POST, not the API.
FORM="$(mktemp -t burrito-app-manifest).html"
cat > "$FORM" <<EOF
<form action="https://github.com/settings/apps/new" method="post">
  <input type="hidden" name="manifest" value='${MANIFEST}'>
  <input type="submit" value="Create the burrito-brassberry GitHub App">
</form>
EOF

echo "Opening the manifest form in your browser. Click the button, then GitHub"
echo "redirects to https://burrito.dixneuf19.fr/manifest-redirect?code=... (the"
echo "page 404s, that is expected: copy the code from the URL bar)."
open "$FORM"

read -r -p "code= " CODE

echo "Converting the manifest code into app credentials..."
CONVERSION="$(gh api --method POST "/app-manifests/${CODE}/conversions")"

APP_ID="$(jq -r .id <<<"$CONVERSION")"
APP_SLUG="$(jq -r .slug <<<"$CONVERSION")"
PEM="$(jq -r .pem <<<"$CONVERSION")"
WEBHOOK_SECRET="$(jq -r .webhook_secret <<<"$CONVERSION")"

echo "Storing credentials in Bitwarden Secrets Manager..."
bws secret create burrito-github-app-id "$APP_ID" "$BW_PROJECT_ID" >/dev/null
bws secret create burrito-github-app-private-key "$PEM" "$BW_PROJECT_ID" >/dev/null
bws secret create burrito-github-webhook-secret "$WEBHOOK_SECRET" "$BW_PROJECT_ID" >/dev/null

cat <<EOF

App ${APP_SLUG} (id ${APP_ID}) created; app id, private key and webhook secret
are in Bitwarden. Next steps:

1. Install the app on brassberry-gitops only:
     open https://github.com/apps/${APP_SLUG}/installations/new
2. Grab the installation id from the URL you land on
   (https://github.com/settings/installations/<ID>) and store it:
     bws secret create burrito-github-app-installation-id <ID> ${BW_PROJECT_ID}
3. Adopt the 4 secrets in terraform/bitwarden (import blocks, see
   terraform/bitwarden/github_app.tf) and run terraform apply there.
4. direnv reload, then in terraform/github: terraform init && terraform apply
   (imports the installation<->repo binding, see README.md).
EOF
