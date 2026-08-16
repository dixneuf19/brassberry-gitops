# ── New secrets (auto-generated) ──────────────────────────────────────────────

resource "bitwarden-secrets_secret" "navidrome_password_encryption_key" {
  key        = "navidrome-password-encryption-key"
  project_id = var.bw_project_id
  note       = "Navidrome password encryption key (auto-generated)"

  length  = 64
  special = false
}

# ── Secrets sourced from another Terraform root ───────────────────────────────
# Apply terraform/scaleway first, these read its outputs from the remote state.

resource "bitwarden-secrets_secret" "cnpg_backup_access_key_id" {
  key        = "cnpg-backup-access-key-id"
  project_id = var.bw_project_id
  note       = "Scaleway API key ID for CloudNativePG backups"

  value = data.terraform_remote_state.scaleway.outputs.cnpg_backup_access_key_id
}

resource "bitwarden-secrets_secret" "cnpg_backup_secret_access_key" {
  key        = "cnpg-backup-secret-access-key"
  project_id = var.bw_project_id
  note       = "Scaleway API secret key for CloudNativePG backups"

  value = data.terraform_remote_state.scaleway.outputs.cnpg_backup_secret_access_key
}

# ── Imported secrets ─────────────────────────────────────────────────────────
# These already exist in Bitwarden. CAUTION: every generation attribute of this
# provider is Optional+Computed, so an adopted resource without ignore_changes
# gets its value REGENERATED on the first apply after import (happened
# 2026-04-06 and 2026-08-15).
#
# To get the secret IDs, run:
#   bws secret list --output json | jq -r '.[] | select(.key | test("baj-mysql|karakeep")) | "\(.key) = \(.id)"'
#
# Then fill in the IDs in imports.tf and run: terraform plan

resource "bitwarden-secrets_secret" "baj_mysql_root_password" {
  key        = "baj-mysql-root-password"
  project_id = var.bw_project_id
  note       = "MySQL root password for og-baj-website"
  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "baj_mysql_password" {
  key        = "baj-mysql-password"
  project_id = var.bw_project_id
  note       = "MySQL app password for og-baj-website"
  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "karakeep_nextauth_secret" {
  key        = "karakeep-nextauth-secret"
  project_id = var.bw_project_id
  note       = "NextAuth session signing key for Karakeep"
  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "karakeep_meili_master_key" {
  key        = "karakeep-meili-master-key"
  project_id = var.bw_project_id
  note       = "MeiliSearch master key for Karakeep"
  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "burrito_datastore_encryption_key" {
  key        = "burrito-datastore-encryption-key"
  project_id = var.bw_project_id
  note       = "Burrito datastore encryption-at-rest key (auto-generated)"

  length  = 64
  special = false
}


resource "bitwarden-secrets_secret" "burrito_datastore_access_key_id" {
  key        = "burrito-datastore-access-key-id"
  project_id = var.bw_project_id
  note       = "Scaleway API key ID for the Burrito datastore"

  value = data.terraform_remote_state.scaleway.outputs.burrito_datastore_access_key_id
}

resource "bitwarden-secrets_secret" "burrito_datastore_secret_access_key" {
  key        = "burrito-datastore-secret-access-key"
  project_id = var.bw_project_id
  note       = "Scaleway API secret key for the Burrito datastore"

  value = data.terraform_remote_state.scaleway.outputs.burrito_datastore_secret_access_key
}

resource "bitwarden-secrets_secret" "burrito_runner_access_key_id" {
  key        = "burrito-runner-access-key-id"
  project_id = var.bw_project_id
  note       = "Scaleway API key ID for burrito runner pods"

  value = data.terraform_remote_state.scaleway.outputs.burrito_runner_access_key_id
}

resource "bitwarden-secrets_secret" "burrito_runner_secret_access_key" {
  key        = "burrito-runner-secret-access-key"
  project_id = var.bw_project_id
  note       = "Scaleway API secret key for burrito runner pods"

  value = data.terraform_remote_state.scaleway.outputs.burrito_runner_secret_access_key
}

resource "bitwarden-secrets_secret" "scaleway_organization_id" {
  key        = "scaleway-organization-id"
  project_id = var.bw_project_id
  note       = "Scaleway organization ID"

  value = data.terraform_remote_state.scaleway.outputs.scaleway_organization_id
}

resource "bitwarden-secrets_secret" "scaleway_default_project_id" {
  key        = "scaleway-default-project-id"
  project_id = var.bw_project_id
  note       = "Scaleway default project ID"

  value = data.terraform_remote_state.scaleway.outputs.scaleway_default_project_id
}

# ── Cloud layer (adopted, values written with bws; see the regen CAUTION above) ──

resource "bitwarden-secrets_secret" "github_user" {
  key        = "github-user"
  project_id = var.bw_project_id
  note       = "GitHub username for cloud-init user (cloud layer)"

  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "oci_compartment_id" {
  key        = "oci-compartment-id"
  project_id = var.bw_project_id
  note       = "OCI compartment OCID (cloud layer)"

  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "oci_node_ips" {
  key        = "oci-node-ips"
  project_id = var.bw_project_id
  note       = "Tailscale IPs of cluster nodes, JSON list for TF_VAR_node_ips (cloud layer)"

  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "tailscale_oauth_client_id" {
  key        = "tailscale-oauth-client-id"
  project_id = var.bw_project_id
  note       = "Tailscale OAuth client ID for the terraform tailscale provider (cloud layer)"

  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "tailscale_oauth_client_secret" {
  key        = "tailscale-oauth-client-secret"
  project_id = var.bw_project_id
  note       = "Tailscale OAuth client secret for the terraform tailscale provider (cloud layer)"

  lifecycle {
    ignore_changes = [value, length]
  }
}

resource "bitwarden-secrets_secret" "oci_api_private_key" {
  key        = "oci-api-private-key"
  project_id = var.bw_project_id
  note       = "OCI API private key PEM (cloud layer provider)"

  lifecycle {
    ignore_changes = [value, length]
  }
}
