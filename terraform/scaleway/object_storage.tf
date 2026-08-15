# Existing S3 bucket used for Terraform state across all layers.
# Import with: terraform import scaleway_object_bucket.tfstates fr-par/dixneuf19-tfstates
resource "scaleway_object_bucket" "tfstates" {
  name = "dixneuf19-tfstates"

  versioning {
    enabled = true
  }
}
