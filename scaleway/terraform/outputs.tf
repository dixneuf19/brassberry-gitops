output "cnpg_backup_access_key_id" {
  description = "Scaleway API key ID for CloudNativePG backups"
  value       = scaleway_iam_api_key.cnpg_backups.access_key
  sensitive   = true
}

output "cnpg_backup_secret_access_key" {
  description = "Scaleway API secret key for CloudNativePG backups"
  value       = scaleway_iam_api_key.cnpg_backups.secret_key
  sensitive   = true
}
