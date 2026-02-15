# ZFS Architecture -- Why and How

This document explains the ZFS concepts behind our Proxmox storage setup,
why each choice was made, and how the pieces fit together.

Reference: [ZFS for Dummies](https://ikrima.dev/dev-notes/homelab/zfs-for-dummies/)

---

## ZFS in 5 Minutes

ZFS is both a **filesystem** (like ext4 or NTFS) and a **volume manager**
(like LVM) rolled into one. It handles disks, RAID, checksums, compression,
and snapshots -- all in a single layer.

### The 3 Layers

```
┌──────────────────────────────────────────┐
│              Datasets                    │  <- filesystems you actually use
│   (compression, snapshots, quotas...)    │     like folders with superpowers
├──────────────────────────────────────────┤
│              Pool (zpool)                │  <- groups vdevs into one storage
│   (aggregates space from vdevs)          │     namespace, like a big bucket
├──────────────────────────────────────────┤
│              vdevs                       │  <- groups of disks with redundancy
│   (single, mirror, raidz1, raidz2...)   │     this is where RAID happens
└──────────────────────────────────────────┘
```

**vdev** (virtual device): One or more physical disks grouped together.
The redundancy level is set here -- a single disk, a mirror, or RAIDZ.
Once a vdev is created, you cannot change its type or remove disks from it.

**Pool** (zpool): One or more vdevs combined. The pool stripes data across
its vdevs. All space from all vdevs is available to all datasets in the pool.
You can add vdevs to a pool later to grow it.

**Dataset**: A filesystem inside a pool. Datasets inherit properties from
their parent (pool or parent dataset) but can override them. Each dataset
can have its own compression, record size, snapshots, etc. Datasets are
cheap to create -- they share the pool's space dynamically (no pre-allocation).

### RAIDZ Levels (our choices)

| Type | Min disks | Can lose | Usable space (4 disks) | Use case |
|------|-----------|----------|------------------------|----------|
| Single | 1 | 0 | 100% | Performance, replaceable data |
| Mirror | 2 | N-1 | 50% | Max redundancy |
| RAIDZ1 | 3 | 1 | 75% (3 of 4) | Good balance, small arrays |
| **RAIDZ1** | **3** | **1** | **75% (3 of 4)** | **Our choice: good balance** |
| RAIDZ3 | 5 | 3 | 40% | Very large arrays |

**Why RAIDZ1 for our HDDs?** With 4 disks, RAIDZ1 gives us 75% usable space
(~36TB) vs 50% with RAIDZ2 (~24TB). We accept the risk of losing data if
2 disks fail simultaneously during a rebuild. Mitigations: regular backups
to external/cloud, and the plan to add more disks later (a second vdev can
use RAIDZ2 for better redundancy as the array grows).

### Key Properties

| Property | What it does | Our choices |
|----------|-------------|-------------|
| `compression` | Compresses data transparently | `lz4` (fast, NVMe) / `zstd` (better ratio, HDDs) |
| `atime` | Updates access time on every read | `off` -- saves tons of writes |
| `recordsize` | Block size for files | `128K` default / `1M` for large files |
| `ashift` | Sector size alignment (2^n) | `12` = 4K sectors (matches modern disks) |
| `xattr=sa` | Store extended attributes in inodes | Faster than default (saves a lookup) |
| `dnodesize=auto` | Let ZFS pick optimal dnode size | Better for xattr=sa |
| `autoexpand` | Pool grows if disks are replaced with larger ones | `on` |

**Why lz4 vs zstd?**
- `lz4`: Nearly zero CPU cost, slight compression. Perfect for NVMe where
  latency matters more than space.
- `zstd`: Better compression ratio but uses more CPU. Worth it on HDDs
  where the bottleneck is disk I/O, not CPU. Compressing data means fewer
  bytes to read/write on slow spinning disks.

**Why recordsize=1M for some datasets?**
ZFS reads/writes in blocks of `recordsize`. For large files (ISOs, backups,
media), using 1M blocks means fewer metadata operations and sequential I/O
patterns that HDDs love. For small files or databases, the default 128K
(or even smaller) is better to avoid wasting space.

---

## Our Architecture

```
                         jonbonas (Proxmox VE)
    ┌────────────────────────────────────────────────────────────────┐
    │                                                                │
    │   NVMe 1TB (OS)         NVMe 2TB             4x HDD 12TB     │
    │   ┌───────────┐         ┌───────────┐        ┌─────────────┐  │
    │   │  single   │         │  single   │        │   RAIDZ1    │  │
    │   │   vdev    │         │   vdev    │        │    vdev     │  │
    │   └─────┬─────┘         └─────┬─────┘        │ ┌─┬──┬──┐  │  │
    │         │                     │              │ │a│b │c │d │  │
    │         │                     │              └─┴─┴──┴──┴──┘  │
    │   ┌─────┴─────┐         ┌─────┴─────┐        ┌─────┴──────┐  │
    │   │   rpool   │         │ fastpool  │        │    tank    │  │
    │   │ (pool)    │         │ (pool)    │        │   (pool)   │  │
    │   └─────┬─────┘         └─────┬─────┘        └─────┬──────┘  │
    │         │                     │                    │         │
    │         │               ┌─────┴─────┐        ┌─────┴──────┐  │
    │    Proxmox OS           │ vm-disks  │        │ backups    │  │
    │    (root, swap,         │ ct-data   │        │ media      │  │
    │     boot, etc.)         └───────────┘        │ iso        │  │
    │                          lz4 / 128K          │ templates  │  │
    │    lz4 / atime=off                           │ data       │  │
    │                                              └────────────┘  │
    │                                               zstd / mixed   │
    │                                               recordsizes    │
    └────────────────────────────────────────────────────────────────┘
```

### 3 Pools, 3 Purposes

| Pool | Disk(s) | Redundancy | Compression | Role |
|------|---------|------------|-------------|------|
| `rpool` | NVMe 1TB | None (single) | lz4 | **OS only.** Created by Proxmox installer. We just tune properties. Losing this = reinstall Proxmox (15 min). |
| `fastpool` | NVMe 2TB | None (single) | lz4 | **VM/container workloads.** Fast storage for K8s workers. Losing this = re-create VMs from code (Terraform + cloud-init). |
| `tank` | 4x HDD 12TB | RAIDZ1 | zstd | **Bulk storage + backups.** Survives 1 disk failure (~36TB usable). Plan to add vdevs later. |

### Why 3 Separate Pools (not 1 big pool)?

A pool stripes data across all its vdevs. If we put NVMe and HDD vdevs
in the same pool, ZFS would write data to both, and the HDDs would become
the bottleneck for everything. Separate pools let us:

1. **Match speed to workload**: VMs on NVMe, archives on HDD
2. **Isolate failure domains**: A dead HDD doesn't affect VM performance
3. **Use different compression**: lz4 for latency, zstd for space
4. **Tune recordsize per use case**: 128K for VMs, 1M for large files

### Why No Redundancy on NVMe Pools?

- `rpool` (OS): A reinstall from USB takes 15 minutes. All config is in
  Ansible/Terraform -- the entire state can be rebuilt from code.
- `fastpool` (VMs): VMs are created by Terraform with cloud-init. K8s state
  is in etcd on the Raspberry Pi cluster. Nothing on fastpool is unique.

Redundancy costs 50%+ of your NVMe space. For data that can be rebuilt
from code in minutes, it's not worth it. Spend the redundancy budget on
`tank` where irreplaceable data lives.

### Dataset Layout

```
rpool/                          # Proxmox OS (installer-created)
├── ROOT/pve-1                  # Root filesystem
├── data                        # LXC/VM storage (default)
└── ...                         # (managed by Proxmox)

fastpool/                       # NVMe 2TB performance pool
├── vm-disks                    # K8s worker VM disk images
└── ct-data                     # Container volumes

tank/                           # HDD capacity pool (RAIDZ1)
├── backups      (1M rec)       # Proxmox VM/CT backups (vzdump)
├── media        (1M rec)       # Media files (NFS/Samba share)
├── iso          (1M rec)       # ISO images for VM installs
├── templates    (128K rec)     # Container templates (small files)
└── data         (128K rec)     # General-purpose storage
```

### How Data Flows

```
  Terraform creates VMs ──────> fastpool/vm-disks (NVMe, fast I/O)
                                     │
                                     │ vzdump backup
                                     ▼
                              tank/backups (HDD, compressed, redundant)

  ISO downloads ──────────────> tank/iso (HDD, large files, 1M blocks)

  Media / NAS shares ─────────> tank/media (HDD, zstd saves space)

  Cloud-init templates ───────> tank/templates (HDD, small files)
```

---

## Growing the Storage Later

### Add a disk to the existing RAIDZ1 vdev (OpenZFS 2.2+)

```bash
# Example: add a 5th HDD to the existing RAIDZ1
zpool attach tank raidz1-0 /dev/sde
```

After this, the vdev becomes a 5-disk RAIDZ1 (still lose 1 disk to parity,
gain 1 disk of usable space). Note: existing data keeps the old parity
ratio until rewritten.

### Add a whole new vdev to the pool

```bash
# Example: add 4 new HDDs as a second vdev (can choose a different RAIDZ level)
zpool add tank raidz2 /dev/sde /dev/sdf /dev/sdg /dev/sdh
```

This doubles the pool's capacity and throughput (ZFS stripes across vdevs).
All datasets in `tank` automatically see the new space.

### Replace a disk with a larger one

```bash
zpool replace tank /dev/sda /dev/new-disk
# Repeat for each disk. With autoexpand=on, pool grows automatically.
```

---

## Quick ZFS Commands Cheatsheet

```bash
# Pool status (health, scrub progress, errors)
zpool status

# List pools with space usage
zpool list

# List all datasets with space and mountpoints
zfs list

# Check a specific property
zfs get compression tank
zfs get recordsize tank/backups

# Manual scrub (run monthly, checks all checksums)
zpool scrub tank

# Snapshot a dataset
zfs snapshot tank/backups@2025-02-15

# List snapshots
zfs list -t snapshot

# Send a snapshot to another pool or remote host
zfs send tank/backups@2025-02-15 | zfs recv backup-pool/backups
zfs send tank/backups@2025-02-15 | ssh remote zfs recv tank/backups
```

---

## What Manages What

| Layer | Tool | What it does |
|-------|------|-------------|
| Disks -> Pools -> Datasets | **Ansible** (`proxmox-zfs.yaml`) | Creates zpools, vdevs, datasets, sets all properties |
| Pools -> Proxmox Storage | **Terraform** (`storage.tf`) | Registers pools as Proxmox storage backends |
| Proxmox Storage -> VMs | **Terraform** (`vms.tf`) | Creates VMs on the registered storage |
