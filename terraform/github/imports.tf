# Adoption of objects that predate this root. Import blocks are no-ops once
# the resources are in the state.

# ArgoCD push webhook, created by hand long before this root.
import {
  to = github_repository_webhook.argocd
  id = "brassberry-gitops/442446137"
}
