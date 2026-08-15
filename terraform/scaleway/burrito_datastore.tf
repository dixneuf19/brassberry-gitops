# Object Storage permission sets are project-scoped, never bucket-scoped, so the
# datastore credentials live in their own project, away from dixneuf19-tfstates.
resource "scaleway_account_project" "burrito_datastore" {
  name        = "burrito-datastore"
  description = "Burrito TACoS datastore (plan artifacts, runner logs, git bundles)"
}

resource "scaleway_object_bucket" "burrito_datastore" {
  name       = "dixneuf19-burrito-datastore"
  region     = "fr-par"
  project_id = scaleway_account_project.burrito_datastore.id

  # Burrito never deletes datastore objects itself (documented gap)
  lifecycle_rule {
    id      = "expire-artifacts"
    enabled = true

    expiration {
      days = 90
    }
  }
}

resource "scaleway_iam_application" "burrito_datastore" {
  name        = "burrito-datastore"
  description = "Burrito datastore access to dixneuf19-burrito-datastore"
}

resource "scaleway_iam_policy" "burrito_datastore" {
  name           = "burrito-datastore"
  description    = "Object Storage access limited to the burrito-datastore project"
  application_id = scaleway_iam_application.burrito_datastore.id

  rule {
    project_ids = [scaleway_account_project.burrito_datastore.id]

    permission_set_names = [
      "ObjectStorageBucketsRead",
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
    ]
  }
}

resource "scaleway_iam_api_key" "burrito_datastore" {
  application_id = scaleway_iam_application.burrito_datastore.id
  description    = "Burrito datastore"

  # S3 clients cannot pass a project ID, the key's default project is used instead.
  default_project_id = scaleway_account_project.burrito_datastore.id

  # Org policy mandates an expiry. The datastore breaks past this date,
  # rotate by bumping it and re-running both TF roots.
  expires_at = "2027-08-15T00:00:00Z"
}
