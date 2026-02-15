# =============================================================================
# Category C: htpasswd-based secrets (generated random passwords)
# TF generates random passwords and stores plaintext in Scaleway SM.
# ESO renders the htpasswd format using bcrypt template function.
# =============================================================================

# --- ingress-nginx basic-auth ---

resource "random_password" "basic_auth" {
  length  = 24
  special = false
}

resource "scaleway_secret" "basic_auth" {
  name        = "basic-auth"
  path        = "/k8s"
  description = "Basic auth credentials for ingress-nginx (htpasswd)"
}

resource "scaleway_secret_version" "basic_auth" {
  secret_id = scaleway_secret.basic_auth.id
  data = jsonencode({
    username = var.basic_auth_username
    password = random_password.basic_auth.result
  })
}

# --- netflix files-auth ---

resource "random_password" "files_auth" {
  length  = 24
  special = false
}

resource "scaleway_secret" "files_auth" {
  name        = "files-auth"
  path        = "/k8s"
  description = "Basic auth credentials for Netflix files (htpasswd)"
}

resource "scaleway_secret_version" "files_auth" {
  secret_id = scaleway_secret.files_auth.id
  data = jsonencode({
    username = "netflix"
    password = random_password.files_auth.result
  })
}

# --- lms-yoshi basic-auth ---

resource "random_password" "yoshi_basic_auth" {
  length  = 24
  special = false
}

resource "scaleway_secret" "yoshi_basic_auth" {
  name        = "yoshi-basic-auth"
  path        = "/k8s"
  description = "Basic auth credentials for Radio Yoshi (htpasswd)"
}

resource "scaleway_secret_version" "yoshi_basic_auth" {
  secret_id = scaleway_secret.yoshi_basic_auth.id
  data = jsonencode({
    username = "clauss"
    password = random_password.yoshi_basic_auth.result
  })
}
