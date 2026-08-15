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

output "burrito_datastore_access_key_id" {
  description = "Scaleway API key ID for the Burrito datastore"
  value       = scaleway_iam_api_key.burrito_datastore.access_key
  sensitive   = true
}

output "burrito_datastore_secret_access_key" {
  description = "Scaleway API secret key for the Burrito datastore"
  value       = scaleway_iam_api_key.burrito_datastore.secret_key
  sensitive   = true
}

output "burrito_runner_access_key_id" {
  description = "Scaleway API key ID for burrito runner pods"
  value       = scaleway_iam_api_key.burrito_runner.access_key
  sensitive   = true
}

output "burrito_runner_secret_access_key" {
  description = "Scaleway API secret key for burrito runner pods"
  value       = scaleway_iam_api_key.burrito_runner.secret_key
  sensitive   = true
}

output "scaleway_organization_id" {
  description = "Scaleway organization ID"
  value       = data.scaleway_account_project.homelab.organization_id
}

output "scaleway_default_project_id" {
  description = "Scaleway homelab (provider default) project ID"
  value       = data.scaleway_account_project.homelab.id
}
