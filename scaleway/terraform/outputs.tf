# =============================================================================
# Outputs: secret IDs for manual version creation (Category B)
# Usage: scw secret version create secret-id=$(terraform output -raw secret_id_xxx) data="$(echo -n 'value' | base64)"
# =============================================================================

# --- Terraform layer secrets ---

output "secret_id_proxmox_api_token" {
  description = "Secret ID for proxmox-api-token (single value)"
  value       = scaleway_secret.proxmox_api_token.id
}

output "secret_id_ssh_public_key" {
  description = "Secret ID for ssh-public-key (single value)"
  value       = scaleway_secret.ssh_public_key.id
}

output "secret_id_gandi_pat" {
  description = "Secret ID for gandi-pat (single value)"
  value       = scaleway_secret.gandi_pat.id
}

# --- K8s app secrets ---

output "secret_id_karakeep_openai" {
  description = "Secret ID for karakeep-openai-api-key (single value)"
  value       = scaleway_secret.karakeep_openai.id
}

output "secret_id_spotify_api_access" {
  description = "Secret ID for spotify-api-access (JSON: SPOTIPY_CLIENT_ID, SPOTIPY_CLIENT_SECRET)"
  value       = scaleway_secret.spotify_api_access.id
}

output "secret_id_fip_slack_bot" {
  description = "Secret ID for fip-slack-bot (JSON: SLACK_CLIENT_ID, SLACK_CLIENT_SECRET, SLACK_SIGNING_SECRET)"
  value       = scaleway_secret.fip_slack_bot.id
}

output "secret_id_fip_telegram_bot" {
  description = "Secret ID for fip-telegram-bot (JSON: BOT_TELEGRAM_TOKEN)"
  value       = scaleway_secret.fip_telegram_bot.id
}

output "secret_id_dank_face_slack_bot" {
  description = "Secret ID for dank-face-slack-bot (JSON: SLACK_CLIENT_ID, SLACK_CLIENT_SECRET, SLACK_SIGNING_SECRET)"
  value       = scaleway_secret.dank_face_slack_bot.id
}

output "secret_id_dank_face_telegram_token" {
  description = "Secret ID for dank-face-telegram-token (JSON: TELEGRAM_TOKEN)"
  value       = scaleway_secret.dank_face_telegram_token.id
}

output "secret_id_grafana_admin" {
  description = "Secret ID for grafana-admin (JSON: admin-user, admin-password)"
  value       = scaleway_secret.grafana_admin.id
}

