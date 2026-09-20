terraform {
  required_version = "1.16.3"

  required_providers {
    bitwarden-secrets = {
      source  = "bitwarden/bitwarden-secrets"
      version = "1.0.1"
    }
  }
}
