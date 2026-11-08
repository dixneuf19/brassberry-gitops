# Virtual machines (Proxmox)

One VM: `k8s-worker-1` (vmid 200), 4 cores, 8G, 200G disk on `fastpool/vm-disks`
(single NVMe, no redundancy), created by `terraform/proxmox/vms.tf` with cloud-init.
The Oracle Cloud VM is a stateless nginx stream proxy rebuilt by Terraform, no backup.

## Physical vs logical for a VM

| | Physical: vzdump / PBS | Logical: rebuild from code |
|---|---|---|
| What | image of the zvol, snapshot-consistent | `terraform apply` + cloud-init + k0sctl join |
| Time to recover | minutes, restores the node as it was | ~30 min, node is fresh, PVC data is gone |
| Covers `local-path` data | yes, it is inside the disk | no |

The VM itself is rebuildable. What is not: the `local-path` PVCs living in
`/opt/local-path-provisioner` on its disk, today Immich's Postgres (recoverable from S3),
Karakeep's data (recoverable from the NAS tarball, up to a day old), Immich's ML cache
(♻️).

## Current state

| Item | State |
|---|---|
| vzdump job | none (`/etc/pve/jobs.cfg` absent). `tank-backups` storage is registered and empty |
| PBS | LXC definition commented out in `terraform/proxmox/containers.tf`, `proxmox-backup-client` binary is installed on the host |
| ZFS snapshot of `fastpool/vm-disks` | none |
| Burrito layer for this root | `autoApply: false` forever, because an apply can recreate the VM |

Status 🟡: the VM is code, the data on it has app-level backups, but a `fastpool` failure
still costs up to 24h of Karakeep and a full CNPG restore.

## Plan

Cheapest first: sanoid daily snapshots of `fastpool/vm-disks` (7 kept) for fast undo of a
bad upgrade. Then a weekly vzdump to `tank/backups` (`zstd`, keep 2) so the node can be
restored without re-joining. PBS only if a second VM appears. See
[../tools/proxmox-vzdump-pbs.md](../tools/proxmox-vzdump-pbs.md).

## Restore

- From vzdump: `qmrestore /tank/backups/dump/vzdump-qemu-200-<stamp>.vma.zst 200 --storage fastpool`.
- From code: `cd terraform/proxmox && terraform apply`, then `make k0sctl`, then let ArgoCD
  reschedule; recover Immich DB from S3 and Karakeep from the tarball.
