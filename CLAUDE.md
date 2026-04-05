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

### Terraform (3 separate roots)

```bash
cd scaleway/terraform && terraform plan   # Scaleway S3 (TF state backend)
cd proxmox/terraform && terraform plan    # Proxmox VMs, storage, users
cd oci-arm && terraform plan              # Oracle Cloud ARM + DigitalOcean + Gandi DNS
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

- **`scaleway/terraform/`** — Foundation layer. Manages the S3 bucket (Terraform state backend).
- **`proxmox/terraform/`** — Proxmox VE resources (VMs, storage, users, cloud-init). Depends on secrets from Bitwarden Secrets Manager.
- **`oci-arm/`** — Cloud worker nodes (Oracle Cloud ARM, DigitalOcean droplet, Gandi DNS).
- **`cluster/`** — k0s cluster config (`k0sctl.yaml`) and lifecycle playbooks.
- **`raspberry-pi/`** — Pi provisioning (cloud-init templates, image customization scripts).
- **`ansible/`** — Shared inventory and generic playbooks. All nodes are on the Tailscale mesh VPN.

### Secrets Flow

Two paths from Bitwarden Secrets Manager:
- **Terraform**: `direnv` reads secrets via `bws secret list` → exports as `TF_VAR_*`
- **Kubernetes**: External Secrets Operator syncs via `ExternalSecret` resources in each app's Helm templates, using a `ClusterSecretStore` named `bitwarden-secrets-manager` (backed by `bitwarden-sdk-server` running in the `external-secrets` namespace)

### Adding a New Kubernetes App

1. Create `gitops/<namespace>/<chart>/` with Chart.yaml, values.yaml, templates/
2. Add a Makefile (copy from existing app — all follow the same pattern)
3. Add an entry in `gitops/argocd/apps/values.yaml` with name, namespace, and path
4. If secrets are needed: create secrets in Bitwarden Secrets Manager (via `bws` CLI or web UI) and add `ExternalSecret` in templates/

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
