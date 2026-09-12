# Secrets and Terraform state

## Bitwarden Secrets Manager

Root of every secret: 26 secrets on the EU instance, consumed by Terraform (`direnv` +
`bws`) and by the cluster (ESO `ClusterSecretStore bitwarden-secrets-manager`).

| | State |
|---|---|
| Vendor durability | Bitwarden SaaS, no SLA on the free tier |
| Our export | **none**. No `bws secret list` dump, no printed recovery sheet |
| Known incident | the Terraform provider regenerated adopted secrets on 2026-04-06 and 2026-08-15 (`ignore_changes` now mandatory, see `terraform/bitwarden/secrets.tf`) |
| Secrets whose loss is unrecoverable | `oci-api-private-key`, `tailscale-oauth-client-*`, `burrito-datastore-encryption-key`, `navidrome-password-encryption-key`, GitHub App private key, `karakeep-nextauth-secret` |

Status 🟡. Plan: quarterly `bws secret list -o json` into an `age`-encrypted file on
`/tank/data/backups/bitwarden/`, key held offline. Document it as a checklist in
`terraform/bitwarden/README.md`, not a script.

## Terraform state

Bucket `dixneuf19-tfstates`, Scaleway `fr-par`, **versioning enabled**, no lifecycle
expiry, S3 native locking. Holds the state of the `scaleway`, `proxmox`, `bitwarden`,
`cloud`, `github` roots. Status ✅.

Caveats:

- The bucket is managed by the `scaleway` root whose own state is inside it. Recovery
  from bucket loss starts with `terraform import` of the bucket.
- The `burrito-runner` IAM key has org-wide `ObjectStorageFullAccess`: it can delete this
  bucket and the CNPG backup bucket. Versioning protects the first, nothing protects the
  second. See [../tools/scaleway-object-storage.md](../tools/scaleway-object-storage.md).
- `terraform/cloud/terraform.tfstate.backup` is an untracked local file on the laptop.
  It is residue, not a backup. Delete it when convenient.

## Burrito datastore

Bucket `dixneuf19-burrito-datastore`, plan artifacts and logs, 90d lifecycle, encrypted
at rest with `burrito-datastore-encryption-key`. Derived data (♻️), but the encryption key
is class P.

## Hand-made, non-IaC items

Documented in their READMEs, listed here so a rebuild does not forget them: the
`burrito-brassberry` GitHub App (no API to create Apps), the `terraform@pam` Proxmox
token, the ArgoCD webhook import, the ghcr package visibility, the Proxmox post-install
script.
