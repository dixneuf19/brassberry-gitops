# Scaleway provider reads credentials from environment variables:
#   SCW_ACCESS_KEY, SCW_SECRET_KEY, SCW_DEFAULT_PROJECT_ID, SCW_DEFAULT_ORGANIZATION_ID
# These are set by direnv via `scw config get`.
provider "scaleway" {
  region = "fr-par"
  zone   = "fr-par-1"
}
