# =============================================================================
# Category C: htpasswd-based secrets (manual passwords from password manager)
# Terraform creates the secret container only. Versions are populated manually.
# ESO renders the htpasswd format using bcrypt template function.
# Secret format: {"username":"...","password":"..."}
# =============================================================================

# --- ingress-nginx basic-auth ---

resource "scaleway_secret" "basic_auth" {
  name        = "basic-auth"
  path        = "/k8s"
  description = "Basic auth credentials for ingress-nginx (JSON: username, password) -- ESO renders htpasswd"
}

# --- netflix files-auth ---

resource "scaleway_secret" "files_auth" {
  name        = "files-auth"
  path        = "/k8s"
  description = "Basic auth credentials for Netflix files (JSON: username, password) -- ESO renders htpasswd"
}

# --- lms-yoshi basic-auth ---

resource "scaleway_secret" "yoshi_basic_auth" {
  name        = "yoshi-basic-auth"
  path        = "/k8s"
  description = "Basic auth credentials for Radio Yoshi (JSON: username, password) -- ESO renders htpasswd"
}
