# The GitHub App itself cannot be Terraform-managed (GitHub has no API to create
# apps); it is created once from manifest.json, see README.md. This only pins
# which repositories the installation covers.
resource "github_app_installation_repository" "burrito_brassberry_gitops" {
  installation_id = var.burrito_github_app_installation_id
  repository      = "brassberry-gitops"
}
