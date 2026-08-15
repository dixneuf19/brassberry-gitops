output "argocd_github_webhook_secret" {
  description = "Webhook secret for the brassberry-gitops push webhook to ArgoCD"
  value       = bitwarden-secrets_secret.argocd_github_webhook_secret.value
  sensitive   = true
}
