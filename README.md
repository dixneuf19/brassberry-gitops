# brassberry-gitops

Monorepo for my homelab infrastructure: from bare-metal provisioning to GitOps-managed Kubernetes applications.

## Repository Structure

```
.
├── gitops/              # ArgoCD-managed Kubernetes manifests
│   ├── argocd/          # ArgoCD server config + Application definitions
│   ├── monitoring/      # kps, kube-state-metrics, karma
│   ├── logging/         # loki, promtail
│   ├── storage/         # nfs-client, local-path provisioners
│   ├── ingress-nginx/
│   ├── external-secrets/
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
├── proxmox/             # Proxmox VE: terraform + playbooks + docs
│   ├── terraform/
│   ├── playbooks/       # proxmox-bootstrap, proxmox-zfs
│   ├── README.md
│   └── ZFS.md
│
├── oci-arm/             # Oracle Cloud ARM VM: terraform
│
├── raspberry-pi/        # Pi provisioning: image scripts + playbooks
│   ├── fix-ssh-on-pi.*  # Image customization
│   ├── templates/       # Cloud-init templates
│   └── playbooks/       # jellyfin, mounts
│
├── cluster/             # k8s cluster lifecycle
│   ├── k0sctl.yaml      # k0s cluster config
│   └── playbooks/       # kernel-modules, upgrade, nfs-server
│
├── ansible/             # Shared Ansible config
│   ├── hosts.yaml       # Inventory (brassberry nodes, proxmox, etc.)
│   ├── scripts/         # tailscale-hostmap
│   └── playbooks/       # Generic: ping, reboot, tailscale
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
kubectl apply -f gitops/argocd/apps/argocd-apps.yaml
```

## Technologies

- **Kubernetes**: k0s on Raspberry Pi 4 cluster + Oracle Cloud ARM worker
- **GitOps**: ArgoCD with Renovate + ArgoCD Image Updater
- **IaC**: Terraform (Proxmox, OCI)
- **Config Management**: Ansible
- **Networking**: Tailscale mesh VPN
- **Storage**: ZFS (Proxmox), NFS shared storage
