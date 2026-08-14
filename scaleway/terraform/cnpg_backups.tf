# Object Storage permission sets are project-scoped, never bucket-scoped, so the
# backup credentials live in their own project to keep them away from dixneuf19-tfstates.
resource "scaleway_account_project" "cnpg_backups" {
  name        = "cnpg-backups"
  description = "CloudNativePG backup storage"
}

resource "scaleway_object_bucket" "cnpg_backups" {
  name       = "dixneuf19-cnpg-backups"
  region     = "fr-par"
  project_id = scaleway_account_project.cnpg_backups.id

  # Only logical dumps are lifecycled. Barman handles retention under physical/.
  lifecycle_rule {
    id      = "logical-dumps"
    prefix  = "logical/"
    enabled = true

    transition {
      # Scaleway minimum for GLACIER transitions
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "scaleway_iam_application" "cnpg_backups" {
  name        = "cnpg-backups"
  description = "CloudNativePG backups to dixneuf19-cnpg-backups"
}

resource "scaleway_iam_policy" "cnpg_backups" {
  name           = "cnpg-backups"
  description    = "Object Storage access limited to the cnpg-backups project"
  application_id = scaleway_iam_application.cnpg_backups.id

  rule {
    project_ids = [scaleway_account_project.cnpg_backups.id]

    permission_set_names = [
      "ObjectStorageBucketsRead",
      "ObjectStorageObjectsRead",
      "ObjectStorageObjectsWrite",
      "ObjectStorageObjectsDelete",
    ]
  }
}

resource "scaleway_iam_api_key" "cnpg_backups" {
  application_id = scaleway_iam_application.cnpg_backups.id
  description    = "CloudNativePG backups"

  # S3 clients cannot pass a project ID, the key's default project is used instead.
  default_project_id = scaleway_account_project.cnpg_backups.id

  # Org policy mandates an expiry. WAL archiving breaks silently past this date,
  # rotate by bumping it and re-running both TF roots.
  expires_at = "2027-05-20T00:00:00Z"
}
