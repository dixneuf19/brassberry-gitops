# Proxmox Infrastructure as Code

Manages the Proxmox VE homelab server `jonbonas` using:

- **Ansible** for OS-level configuration (repos, packages, ZFS pools, datasets)
- **Terraform** (bpg/proxmox) for Proxmox API resources (storage defs, VMs, users)

Networking: steps 1-3 use the local IP (`192.168.1.30`). After joining the
Tailscale network, all subsequent commands use the hostname `jonbonas` (resolved
via [tailscale-hostmap](https://github.com/mxbi/tailscale-hostmap)).

## Hardware

| Component | Device | Size | Purpose |
|-----------|--------|------|---------|
| NVMe 1TB | Crucial CT1000P3PSSD8 | 931 GB | Proxmox OS (`rpool`, ZFS RAID0) |
| NVMe 2TB | Crucial CT2000P3PSSD8 | 1.8 TB | Performance workloads (`fastpool`) |
| HDDs 3-4x | Seagate ST12000NM0127 | 12 TB each | Capacity + backups (`tank`, RAIDZ1/2) |

## Prerequisites

- Ansible with `community.general` collection >= 11.0.0
- Terraform >= 1.14.5
- SSH key access to `root@192.168.1.30` (initial) then `root@jonbonas` (Tailscale)
- Scaleway account with Object Storage bucket for Terraform state

```bash
# Install Ansible collection
ansible-galaxy collection install community.general

# Scaleway CLI must be configured (credentials used by .envrc for Terraform S3 backend)
scw init
```

## Setup Steps

### 1. Install Proxmox (local IP: 192.168.1.30)

Install Proxmox VE 9.1 from USB key on the NVMe 1TB with ZFS (RAID0).

- Hostname: `jonbonas.local`
- IP: `192.168.1.30/24`
- Gateway: `192.168.1.1`

Then set up SSH key access:

```bash
ssh-keygen -R 192.168.1.30
ssh-copy-id root@192.168.1.30
```

### 2. Run Community Post-Install Script (local IP)

```bash
make proxmox-post-install
```

### 3. Run Ansible Bootstrap (local IP)

Installs packages, tunes rpool, installs Tailscale, creates Terraform API token:

```bash
make proxmox-bootstrap
```

Save the API token output for `terraform.tfvars`.

### 4. Join Tailscale and Update Hosts (transition to Tailscale)

```bash
# On the Proxmox host (via local IP)
ssh root@192.168.1.30 tailscale up

# On your Mac -- update /etc/hosts with Tailscale IPs
make tailscale-hosts

# Verify: jonbonas should now resolve
ssh jonbonas hostname
```

From this point on, all commands use the Tailscale hostname `jonbonas`.

### 5. Run Ansible ZFS Setup (Tailscale)

Creates ZFS pools (`fastpool`, `tank`) and all datasets:

```bash
make proxmox-zfs
```

Before running, verify `hosts.yaml` has the correct devices:
- `fastpool_device`: the NVMe 2TB device path
- `tank_devices`: list of HDD device paths
- `tank_vdev_type`: `raidz1` (3 disks) or `raidz2` (4+ disks)

### 6. Run Terraform (Tailscale)

```bash
cd proxmox/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (API token from step 3, SSH key)

terraform init
terraform plan
terraform apply
```

The `import` blocks in `users.tf` will automatically import the Ansible-created
terraform user, token, and ACL on the first apply.

## ZFS Architecture

See **[ZFS.md](ZFS.md)** for a full explanation of ZFS concepts, architecture
diagrams, why each choice was made, and how to expand storage later.

Quick summary: 3 pools, 3 purposes.

| Pool | Disk(s) | Redundancy | Purpose |
|------|---------|------------|---------|
| `rpool` | NVMe 1TB | Single | Proxmox OS (rebuildable from code) |
| `fastpool` | NVMe 2TB | Single | VM disks, K8s workloads (rebuildable) |
| `tank` | 4x HDD 12TB | RAIDZ1 | Backups, media, data (survives 1 disk failure, ~36TB usable) |

## Future: Enable Proxmox Backup Server

Uncomment the PBS LXC in `terraform/containers.tf` and run `terraform apply`.
See the comments in that file for prerequisites.
