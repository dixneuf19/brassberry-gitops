# brassberry-gitops

Monorepo for my homelab infrastructure: from bare-metal provisioning to GitOps-managed Kubernetes applications.

## Repository Structure

```
.
├── gitops/              # ArgoCD-managed Kubernetes manifests
│   ├── argocd/          # ArgoCD server config + Application definitions
│   ├── monitoring/      # kps, kube-state-metrics, karma
│   ├── traefik/         # Traefik ingress controller
│   ├── storage/         # nfs-client, local-path provisioners
│   ├── external-secrets/ # ESO operator + Bitwarden ClusterSecretStore
│   ├── cert-manager/
│   ├── cnpg-system/     # CloudNativePG operator
│   ├── karakeep/        # Bookmark manager
│   ├── spliit/          # Expense sharing
│   ├── fip/             # FIP radio bots
│   ├── dank-face-bot/   # Telegram/Slack bots
│   ├── lms/             # Lyrion Music Server
│   ├── lms-yoshi/       # Radio Yoshi
│   ├── netflix/         # Media server apps (jellyfin, transmission)
│   └── ...
│
├── terraform/           # All Terraform roots (state in Scaleway S3)
│   ├── scaleway/        # S3 buckets (TF state backend, backups)
│   ├── proxmox/         # Proxmox VE: VMs, storage, users, cloud-init
│   ├── cloud/           # Oracle Cloud ARM VM + DigitalOcean droplet + Gandi DNS
│   └── bitwarden/       # Bitwarden Secrets Manager secrets
│
├── ansible/             # All Ansible: inventory + playbooks
│   ├── hosts.yaml       # Inventory (brassberry nodes, proxmox, etc.)
│   ├── scripts/         # tailscale-hostmap
│   └── playbooks/       # Prefixed by area:
│                        #   ping, reboot, tailscale (generic)
│                        #   cluster-* (kernel-modules, upgrade, nfs-server)
│                        #   proxmox-* (bootstrap, zfs, nfs, grub-aspm, node-exporter)
│                        #   pi-* (jellyfin, mounts)
│
├── cluster/             # k8s cluster config
│   └── k0sctl.yaml      # k0s cluster config
│
├── proxmox/             # Proxmox docs: README.md, ZFS.md, bios.md
│
├── docs/decisions/      # Architecture decision records (ADR)
│
├── raspberry-pi/        # Pi provisioning: image scripts + cloud-init templates
│   ├── fix-ssh-on-pi.*  # Image customization
│   └── templates/       # Cloud-init templates
│
└── Makefile             # Convenience targets for all operations
```

## Quick Start

### Raspberry Pi Image

```bash
cd raspberry-pi
sudo ./fix-ssh-on-pi.bash
```

### Ansible Playbooks

All playbooks use the shared inventory. Run via Make:

```bash
make ping              # Test connectivity
make kernel-modules    # Prepare nodes for k0s
make mounts            # Mount external disks
make nfs-server        # Set up NFS shared storage
make upgrade           # Rolling k8s-aware upgrades
```

### Kubernetes Cluster (k0s)

```bash
make k0sctl            # Bootstrap/update the cluster
make kubeconfig        # Export kubeconfig
```

### Proxmox

```bash
make proxmox-post-install   # Community post-install script (interactive)
make proxmox-bootstrap      # Ansible bootstrap (packages, Tailscale, TF token)
make proxmox-zfs            # Create ZFS pools and datasets
```

See [proxmox/README.md](proxmox/README.md) and [proxmox/ZFS.md](proxmox/ZFS.md) for detailed setup instructions.

### ArgoCD (GitOps)

Bootstrap ArgoCD, then it manages itself and all applications:

```bash
cd gitops/argocd/argo-cd
helm upgrade --install -n argocd --create-namespace argo-cd . -f values.yaml
helm template argocd-apps gitops/argocd/apps/ | kubectl apply -n argocd -f -
```

All applications are defined in `gitops/argocd/apps/values.yaml` and rendered by a Helm chart (app-of-apps pattern).

## Secrets Management

All secrets are managed centrally in **[Bitwarden Secrets Manager](https://vault.bitwarden.eu)** and flow to consumers through two paths:

- **Terraform roots** (`terraform/*`): direnv reads secrets from Bitwarden SM via `bws` CLI and exports them as `TF_VAR_*` environment variables. No `.tfvars` files needed on disk.
- **Kubernetes**: External Secrets Operator syncs secrets from Bitwarden SM into K8s Secrets via `ExternalSecret` resources placed alongside each app's Helm chart.

### Prerequisites

1. Install the [Bitwarden Secrets Manager CLI](https://bitwarden.com/help/secrets-manager-cli/) (`bws`)
2. Create a `.env` file at the repo root with your machine account access token:
   ```
   BWS_ACCESS_TOKEN=<your-token>
   ```
   Generate or retrieve the token from the [machine account page](https://vault.bitwarden.eu/#/sm/512cf254-9f26-4e35-b1d1-b42300bb3dca/machine-accounts/faf79659-0805-4440-a7e8-b42300e93f1e/access).
3. Run `direnv allow` — the `.envrc` will load `.env` automatically

### Adding a new secret

1. Add the secret in Bitwarden Secrets Manager
2. For TF-consumed secrets: add the `TF_VAR_*` export to `.envrc`
3. For K8s secrets: add an `ExternalSecret` resource in the app's chart templates

## CI/CD

- **[argocd-diff-preview](https://github.com/dag-andersen/argocd-diff-preview)**: Runs on every PR to main — renders all ArgoCD Application manifests on both branches and posts a diff as a PR comment. Uses `--traverse-app-of-apps` to recursively discover child applications from the Helm-based app-of-apps chart.
- **Renovate**: Auto-merges minor/patch dependency updates; creates PRs for major versions.

## Technologies

- **Kubernetes**: k0s on Raspberry Pi 4 cluster + Oracle Cloud ARM worker
- **GitOps**: ArgoCD with Renovate + ArgoCD Image Updater + [argocd-diff-preview](https://github.com/dag-andersen/argocd-diff-preview)
- **IaC**: Terraform (Scaleway, Proxmox, OCI)
- **Secrets**: Bitwarden Secrets Manager + External Secrets Operator
- **Config Management**: Ansible
- **Networking**: Tailscale mesh VPN
- **Storage**: ZFS (Proxmox), NFS shared storage
