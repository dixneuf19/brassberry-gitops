# Proxmox vzdump and Proxmox Backup Server (candidate)

Status: **not deployed**. `tank-backups` storage (`/tank/backups`, content `backup`) is
registered and empty. The PBS LXC is written but commented out in
`terraform/proxmox/containers.tf` (vmid 300, 192.168.1.31, bind mount `/tank/backups`).

## vzdump (simple path)

A Proxmox backup job for VM 200, weekly, `zstd`, snapshot mode, to `tank-backups`,
`keep-last 2`. Declared in Terraform once the bpg provider resource is used, or in
Datacenter > Backup in the UI (then it lives in `/etc/pve/jobs.cfg`, outside git).

Gives: a full node image restorable with `qmrestore` in minutes, including every
`local-path` PVC on it. Costs ~50G per copy on `tank` (200G disk, 39G used, compressed).

## PBS (later)

Deduplicated, incremental, verified backups with a UI, and an easy offsite sync to a
second PBS. Overkill for one VM. Revisit if a second VM or LXC with state appears.

## Relation to the other layers

vzdump protects the node, not the data: Immich's DB is already on S3 and Karakeep's data
on the NAS. It mostly buys a faster RTO for `k8s-worker-1` and covers the ML cache and
anything else placed on `local-path` there by mistake. Priority is below sanoid and
restic, see strategy.md.
