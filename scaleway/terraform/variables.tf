# =============================================================================
# Variables for the Scaleway layer
# Category B secrets do NOT have variables -- they are populated manually
# via `scw secret version create` after `terraform apply`.
# =============================================================================

# --- Category C: htpasswd usernames ---

variable "basic_auth_username" {
  description = "Username for ingress-nginx basic auth"
  type        = string
  default     = "admin"
}
