# ── burrito-brassberry GitHub App ─────────────────────────────────────────────
# The app is created once by hand and these secrets are written with bws during
# that procedure (terraform/github/README.md). Terraform adopts them: add import
# blocks with the IDs from
#   bws secret list --output json | jq -r '.[] | select(.key | test("github")) | "\(.key) = \(.id)"'
# then plan/apply and drop the import blocks.

resource "bitwarden-secrets_secret" "burrito_github_app_id" {
  key        = "burrito-github-app-id"
  project_id = var.bw_project_id
  note       = "burrito-brassberry GitHub App ID"
}

resource "bitwarden-secrets_secret" "burrito_github_app_installation_id" {
  key        = "burrito-github-app-installation-id"
  project_id = var.bw_project_id
  note       = "burrito-brassberry GitHub App installation ID"
}

resource "bitwarden-secrets_secret" "burrito_github_app_private_key" {
  key        = "burrito-github-app-private-key"
  project_id = var.bw_project_id
  note       = "burrito-brassberry GitHub App private key (PEM)"
}

resource "bitwarden-secrets_secret" "burrito_github_webhook_secret" {
  key        = "burrito-github-webhook-secret"
  project_id = var.bw_project_id
  note       = "burrito-brassberry GitHub App webhook secret"
}

# ── ArgoCD repo webhook ───────────────────────────────────────────────────────
# Consumed by terraform/github (github_repository_webhook) via remote state and
# by ArgoCD via an ExternalSecret merged into argocd-secret.

resource "bitwarden-secrets_secret" "argocd_github_webhook_secret" {
  key        = "argocd-github-webhook-secret"
  project_id = var.bw_project_id
  note       = "Webhook secret for the brassberry-gitops push webhook to ArgoCD (auto-generated)"

  length  = 64
  special = false
}
