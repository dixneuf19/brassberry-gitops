# Pre-existing hook, adopted via imports.tf.
# Adding the secret authenticates deliveries; ArgoCD gets the same value through
# an ExternalSecret merged into argocd-secret (webhook.github.secret).
resource "github_repository_webhook" "argocd" {
  repository = "brassberry-gitops"
  active     = true
  events     = ["push"]

  configuration {
    url          = "https://argocd.dixneuf19.fr/api/webhook"
    content_type = "json"
    secret       = data.terraform_remote_state.bitwarden.outputs.argocd_github_webhook_secret
    insecure_ssl = false
  }
}
