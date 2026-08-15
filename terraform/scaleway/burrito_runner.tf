data "scaleway_account_project" "homelab" {
  name = "homelab"
}

resource "scaleway_iam_application" "burrito_runner" {
  name        = "burrito-runner"
  description = "Burrito runner pods: org-wide reads for plan, state backend writes"
}

resource "scaleway_iam_policy" "burrito_runner" {
  name           = "burrito-runner"
  description    = "autoApply on the scaleway layer: manage IAM/projects/Object Storage, read the rest"
  application_id = scaleway_iam_application.burrito_runner.id

  # A rule cannot mix scope types: org-scope sets (IAM, projects) and
  # projects-scope sets (products) go in separate rules.
  # IAMManager means this key can escalate its own permissions (documented
  # Scaleway caveat), accepted for autoApply on the scaleway root.
  rule {
    organization_id      = data.scaleway_account_project.homelab.organization_id
    permission_set_names = ["IAMManager", "ProjectManager"]
  }

  rule {
    organization_id      = data.scaleway_account_project.homelab.organization_id
    permission_set_names = ["AllProductsReadOnly", "ObjectStorageFullAccess"]
  }
}

resource "scaleway_iam_api_key" "burrito_runner" {
  application_id = scaleway_iam_application.burrito_runner.id
  description    = "Burrito runner"

  # S3 clients cannot pass a project ID, the key's default project is used instead.
  default_project_id = data.scaleway_account_project.homelab.id

  # Org policy mandates an expiry. Layer plans break past this date,
  # rotate by bumping it and re-running both TF roots.
  expires_at = "2027-08-15T00:00:00Z"
}
