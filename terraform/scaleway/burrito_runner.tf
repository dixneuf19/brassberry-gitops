data "scaleway_account_project" "homelab" {
  name = "homelab"
}

resource "scaleway_iam_application" "burrito_runner" {
  name        = "burrito-runner"
  description = "Burrito runner pods: org-wide reads for plan, state backend writes"
}

resource "scaleway_iam_policy" "burrito_runner" {
  name           = "burrito-runner"
  description    = "Plan-only: read everything, write Object Storage on the default project (tfstates backend + locks)"
  application_id = scaleway_iam_application.burrito_runner.id

  # A rule cannot mix scope types: org-scope sets (IAM, projects) and
  # projects-scope sets (products) go in separate rules.
  rule {
    organization_id      = data.scaleway_account_project.homelab.organization_id
    permission_set_names = ["IAMReadOnly", "ProjectReadOnly"]
  }

  rule {
    organization_id      = data.scaleway_account_project.homelab.organization_id
    permission_set_names = ["AllProductsReadOnly"]
  }

  rule {
    project_ids          = [data.scaleway_account_project.homelab.id]
    permission_set_names = ["ObjectStorageFullAccess"]
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
