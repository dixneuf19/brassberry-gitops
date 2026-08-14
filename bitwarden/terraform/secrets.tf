# ── New secrets (auto-generated) ──────────────────────────────────────────────

resource "bitwarden-secrets_secret" "navidrome_password_encryption_key" {
  key        = "navidrome-password-encryption-key"
  project_id = var.bw_project_id
  note       = "Navidrome password encryption key (auto-generated)"

  length  = 64
  special = false
}

# ── Secrets sourced from another Terraform root ───────────────────────────────
# Apply scaleway/terraform first, these read its outputs from the remote state.

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
# These already exist in Bitwarden. Terraform adopts them without recreating.
#
# To get the secret IDs, run:
#   bws secret list --output json | jq -r '.[] | select(.key | test("baj-mysql|karakeep")) | "\(.key) = \(.id)"'
#
# Then fill in the IDs in imports.tf and run: terraform plan

resource "bitwarden-secrets_secret" "baj_mysql_root_password" {
  key        = "baj-mysql-root-password"
  project_id = var.bw_project_id
  note       = "MySQL root password for og-baj-website"
}

resource "bitwarden-secrets_secret" "baj_mysql_password" {
  key        = "baj-mysql-password"
  project_id = var.bw_project_id
  note       = "MySQL app password for og-baj-website"
}

resource "bitwarden-secrets_secret" "karakeep_nextauth_secret" {
  key        = "karakeep-nextauth-secret"
  project_id = var.bw_project_id
  note       = "NextAuth session signing key for Karakeep"
}

resource "bitwarden-secrets_secret" "karakeep_meili_master_key" {
  key        = "karakeep-meili-master-key"
  project_id = var.bw_project_id
  note       = "MeiliSearch master key for Karakeep"
}
