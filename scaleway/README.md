# Scaleway

Manages Scaleway resources: Object Storage (S3 bucket for Terraform state) and Secret Manager (all secrets for the homelab).

## Prerequisites

- [Scaleway CLI](https://github.com/scaleway/scaleway-cli) installed and configured (`scw init`)
- Terraform >= 1.14.5

## Bootstrap (first time)

1. Make sure the Scaleway CLI is configured:

   ```bash
   scw init
   ```

2. Initialize and import the existing S3 bucket:

   ```bash
   cd scaleway/terraform
   terraform init
   terraform import scaleway_object_bucket.tfstates fr-par/dixneuf19-tfstates
   ```

3. Apply to create all secret containers and generated values:

   ```bash
   terraform apply
   ```

4. Populate the Category B secrets (external API keys) manually. Terraform created the secret containers; you provide the values:

   ```bash
   # Single-value secrets (terraform layer)
   scw secret version create secret-id=$(terraform output -raw secret_id_proxmox_api_token) data="$(echo -n 'terraform@pam!token=secret' | base64)"
   scw secret version create secret-id=$(terraform output -raw secret_id_ssh_public_key) data="$(echo -n 'ssh-ed25519 AAAA...' | base64)"
   scw secret version create secret-id=$(terraform output -raw secret_id_gandi_pat) data="$(echo -n 'your-gandi-pat' | base64)"

   # JSON secrets (K8s apps) -- example for spotify-api-access
   scw secret version create secret-id=$(terraform output -raw secret_id_spotify_api_access) \
     data="$(echo -n '{"SPOTIPY_CLIENT_ID":"...","SPOTIPY_CLIENT_SECRET":"..."}' | base64)"
   ```

   See `secrets_manual.tf` for the full list of secrets and their expected JSON format.

5. Run `direnv allow` from the repo root to load the new `.envrc`.

## Day-to-day usage

After bootstrapping, direnv (`.envrc`) reads `/terraform/*` secrets from Scaleway Secret Manager into `TF_VAR_*` environment variables. Running `terraform plan` or `terraform apply` in any layer works without a tfvars file.

```bash
# From the repo root, direnv loads automatically
cd scaleway/terraform
terraform plan
```

## Secret organization

Secrets are organized in Scaleway Secret Manager using paths:

- `/terraform/*` -- secrets consumed by other TF layers via direnv (`TF_VAR_*`). Versions created manually.
- `/k8s/*` -- secrets synced to Kubernetes via External Secrets Operator. Some versions are TF-generated (Category A: random passwords), some are manually created (Category B: external API keys).
