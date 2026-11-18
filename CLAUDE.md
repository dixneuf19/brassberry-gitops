# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Homelab GitOps monorepo managing infrastructure from bare-metal provisioning to Kubernetes application deployment. The stack runs on a Raspberry Pi 4 cluster + cloud workers (Oracle Cloud ARM, DigitalOcean), managed by ArgoCD, with all secrets centralized in Bitwarden Secrets Manager.

## Common Commands

### Ansible Playbooks (all use `ansible/hosts.yaml` inventory)

```bash
make ping              # Test connectivity to all nodes
make kernel-modules    # Prepare nodes for k0s
make mounts            # Mount external disks on Pis
make nfs-server        # Set up NFS shared storage
make upgrade           # Rolling k8s-aware node upgrades
make proxmox-bootstrap # Ansible bootstrap for Proxmox (packages, Tailscale, TF token)
make proxmox-zfs       # Create ZFS pools and datasets
```

### k0s Cluster

```bash
make k0sctl            # Bootstrap or update the k0s cluster
make kubeconfig        # Export kubeconfig to $KUBECONFIG
```

### Terraform (4 roots under `terraform/`)

```bash
cd terraform/scaleway && terraform plan   # Scaleway S3 (TF state backend, backups)
cd terraform/proxmox && terraform plan    # Proxmox VMs, storage, users
cd terraform/cloud && terraform plan      # Oracle Cloud ARM + DigitalOcean + Gandi DNS
cd terraform/bitwarden && terraform plan  # Bitwarden Secrets Manager secrets
cd terraform/cloudflare && terraform plan # Cloudflare Email Routing (mangococo.fr)
```

All Terraform state is stored in a Scaleway S3 bucket. Credentials are injected via `direnv` from the `scw` CLI (see `.envrc.example`).

### Helm Charts (per-app, inside each chart directory)

```bash
make template    # Render manifests locally (helm template)
make deploy      # Install/upgrade directly via helm
make status      # Check helm release status
make uninstall   # Remove helm release
```

### ArgoCD Bootstrap

```bash
cd gitops/argocd/argo-cd
helm upgrade --install -n argocd --create-namespace argo-cd . -f values.yaml
helm template argocd-apps gitops/argocd/apps/ | kubectl apply -n argocd -f -
```

## Architecture

### GitOps Layer (`gitops/`)

ArgoCD manages all Kubernetes resources. The app-of-apps pattern is used:

1. `gitops/argocd/apps/` — Helm chart that generates all ArgoCD Applications (including itself)
2. `gitops/argocd/apps/values.yaml` — all applications defined in a single file
3. `gitops/<namespace>/<chart>/` — the actual Helm chart (Chart.yaml, values.yaml, templates/)

All apps have automated sync with prune and self-heal enabled. Namespaces are auto-created.

Image updates are handled by ArgoCD Image Updater (configured via ImageUpdater CRDs in the argocd-image-updater chart).

### Infrastructure Layers

- **`terraform/scaleway/`** — Foundation layer. Manages the S3 buckets (Terraform state backend, backups).
- **`terraform/proxmox/`** — Proxmox VE resources (VMs, storage, users, cloud-init). Depends on secrets from Bitwarden Secrets Manager.
- **`terraform/cloud/`** — Cloud worker nodes (Oracle Cloud ARM, DigitalOcean droplet, Gandi DNS).
- **`terraform/bitwarden/`** — Secrets in Bitwarden Secrets Manager.
- **`terraform/cloudflare/`**: Cloudflare Email Routing for mangococo.fr (multi-destination forwarding via an Email Worker).
- **`cluster/`** — k0s cluster config (`k0sctl.yaml`).
- **`raspberry-pi/`** — Pi provisioning (cloud-init templates, image customization scripts).
- **`ansible/`** — Inventory and ALL playbooks, prefixed by area (`cluster-*`, `proxmox-*`, `pi-*`, generic). All nodes are on the Tailscale mesh VPN.
- **`proxmox/`** — Proxmox host documentation (README, ZFS, BIOS notes).

### Secrets Flow

Two paths from Bitwarden Secrets Manager:
- **Terraform** (all roots under `terraform/`): `direnv` reads secrets via `bws secret list` → exports as `TF_VAR_*`
- **Kubernetes**: External Secrets Operator syncs via `ExternalSecret` resources in each app's Helm templates, using a `ClusterSecretStore` named `bitwarden-secrets-manager` (backed by `bitwarden-sdk-server` running in the `external-secrets` namespace)

### Adding a New Kubernetes App

1. Create `gitops/<namespace>/<chart>/` with Chart.yaml, values.yaml, templates/
2. Add a Makefile (copy from existing app — all follow the same pattern)
3. Add an entry in `gitops/argocd/apps/values.yaml` with name, namespace, and path
4. If secrets are needed: create secrets in Bitwarden Secrets Manager (via `bws` CLI or web UI) and add `ExternalSecret` in templates/

### Email Forwarding (mangococo.fr)

Addresses like `contact@mangococo.fr` forward to several mailboxes through a Cloudflare Email Worker (`terraform/cloudflare`). The map lives in the Bitwarden secret `mangococo-email-forwards`, never in git (public repo). To add or remove a destination, or a new source address:

1. `terraform/cloudflare/scripts/forwards.py list`, then `set <src@mangococo.fr> <every destination>` (it replaces the whole list) or `rm <src>`
2. `direnv reload`, then `terraform plan` and `terraform apply` in `terraform/cloudflare` (or let Burrito apply it within ~1h)
3. Tell the user that each new destination must click the Cloudflare verification email before it receives anything

A destination that already exists in Cloudflare (created by hand) needs an `import` block first, or the apply fails on a duplicate.

`ragots@mangococo.fr` is a members-only mailing list (separate Worker, `terraform/cloudflare/ragots.tf`). Members live in the Bitwarden secret `ragots-members`: edit them with `terraform/cloudflare/scripts/ragots.py list|add|rm`, then apply the same way. New members also need to click the verification email.

### CI/CD

- **GitHub Actions**: `argo-cd-diff.yaml` runs on PRs to main — generates ArgoCD diff preview and posts as PR comment
- **Renovate**: Auto-merges minor/patch dependency updates; creates PRs for major versions

### Networking

All nodes (Pis, Proxmox, cloud VMs) are connected via Tailscale. The Ansible inventory resolves hostnames to Tailscale IPs using `ansible/scripts/tailscale-hostmap.py`.

## Prerequisites

- `direnv` (for `.envrc` environment injection)
- `scw` CLI (Scaleway credentials for S3 backend)
- `bws` CLI (Bitwarden Secrets Manager)
- `ansible` (>= 2.10, with `community.general` >= 11.0.0)
- `terraform` (>= 1.14.5)
- `k0sctl` (k0s cluster management)
- `kubectl` + `helm` 3
- SSH keys configured for Tailscale hosts
