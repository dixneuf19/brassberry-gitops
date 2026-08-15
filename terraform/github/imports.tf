# Adoption of objects that predate this root. Import blocks are no-ops once
# the resources are in the state.

# The app installation on the repo is done by hand (README.md step 5).
import {
  to = github_app_installation_repository.burrito_brassberry_gitops
  id = "${var.burrito_github_app_installation_id}:brassberry-gitops"
}

# ArgoCD push webhook, created by hand long before this root.
import {
  to = github_repository_webhook.argocd
  id = "brassberry-gitops/442446137"
}
