# =============================================================================
# Category B: External API keys / credentials (manual input)
# Terraform creates the secret container only. Versions are populated manually:
#   scw secret version create secret-id=<id> data="$(echo -n 'value' | base64)"
# For JSON secrets:
#   scw secret version create secret-id=<id> data="$(echo -n '{"KEY":"value"}' | base64)"
# =============================================================================

# --- Terraform layer secrets (consumed via direnv as TF_VAR_*) ---

resource "scaleway_secret" "proxmox_api_token" {
  name        = "proxmox-api-token"
  path        = "/terraform"
  description = "Proxmox API token for the proxmox TF layer"
}

resource "scaleway_secret" "ssh_public_key" {
  name        = "ssh-public-key"
  path        = "/terraform"
  description = "SSH public key for VM access"
}

resource "scaleway_secret" "gandi_pat" {
  name        = "gandi-pat"
  path        = "/terraform"
  description = "Gandi Personal Access Token for the oci-arm TF layer"
}

# --- K8s app secrets (external API keys) ---

resource "scaleway_secret" "karakeep_openai" {
  name        = "karakeep-openai-api-key"
  path        = "/k8s"
  description = "OpenAI API key for KaraKeep AI features (single value, not JSON)"
}

resource "scaleway_secret" "spotify_api_access" {
  name        = "spotify-api-access"
  path        = "/k8s"
  description = "Spotify API credentials for fip/spotify-api (JSON: SPOTIPY_CLIENT_ID, SPOTIPY_CLIENT_SECRET)"
}

resource "scaleway_secret" "fip_slack_bot" {
  name        = "fip-slack-bot"
  path        = "/k8s"
  description = "Slack credentials for FIP Slack bot (JSON: SLACK_CLIENT_ID, SLACK_CLIENT_SECRET, SLACK_SIGNING_SECRET)"
}

resource "scaleway_secret" "fip_telegram_bot" {
  name        = "fip-telegram-bot"
  path        = "/k8s"
  description = "Telegram bot token for FIP Telegram bot (JSON: BOT_TELEGRAM_TOKEN)"
}

resource "scaleway_secret" "dank_face_slack_bot" {
  name        = "dank-face-slack-bot"
  path        = "/k8s"
  description = "Slack credentials for Dank Face Slack bot (JSON: SLACK_CLIENT_ID, SLACK_CLIENT_SECRET, SLACK_SIGNING_SECRET)"
}

resource "scaleway_secret" "dank_face_telegram_token" {
  name        = "dank-face-telegram-token"
  path        = "/k8s"
  description = "Telegram bot token for Dank Face bot (JSON: TELEGRAM_TOKEN)"
}

# --- K8s app secrets (manual passwords, not random) ---

resource "scaleway_secret" "grafana_admin" {
  name        = "grafana-admin"
  path        = "/k8s"
  description = "Grafana admin credentials (JSON: admin-user, admin-password)"
}
