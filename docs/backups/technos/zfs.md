# ZFS (jonbonas NAS)

Pools on `jonbonas` (Proxmox host, `192.168.1.30`): `rpool` (OS, single NVMe),
`fastpool` (VM disks, single NVMe), `tank` (4x12T RAIDZ1, ~36T usable). Details in
[proxmox/ZFS.md](../../../proxmox/ZFS.md).

## What ZFS gives and does not give

| Mechanism | Kind | Protects against | Does not protect against |
|---|---|---|---|
| RAIDZ1 | redundancy | one dead disk | second disk during resilver, deletion, corruption from a client, fire |
| Scrub | integrity check | silent bit rot (repaired from parity) | anything else |
| Snapshot | physical, point-in-time, same pool | deletion, bad writes, ransomware via NFS | pool loss |
| `zfs send` to another pool or host | physical replication | pool loss | same-site disasters unless the target is offsite |
| `zfs send` to object storage (via `zfs send \| rclone rcat` or a tool like `zfsbackup-go`) | physical, offsite | site loss | needs full stream + incrementals, restore is all-or-nothing per dataset |
| restic/rclone of the mounted dataset | logical, file-level, offsite | site loss, per-file restore | consistency during writes (take from a snapshot mount) |

Snapshots are the physical layer for everything on the NAS: they make a consistent
source for file-level offsite copies (`/tank/media/.zfs/snapshot/<name>/immich`) and
they are the fastest undo button that exists.

## Current state (2026-09-12, live)

| Item | State |
|---|---|
| Snapshots | **0** on every pool. No sanoid, no zfs-auto-snapshot, no cron |
| Replication | none |
| Scrub | monthly, 2nd Sunday, from `/etc/cron.d/zfsutils-linux`. Last: 2026-08-09, 0 errors on `tank` and `fastpool` |
| TRIM | monthly, 1st Sunday, same cron file |
| smartd | active. No ZED mail or alert configured |
| vzdump / PBS | none, see [vms.md](vms.md) |
| Datasets | `tank/media` 44G (Immich), `tank/data` 5.8G (`nfs-jonbonas` PVCs, ad-hoc backups), `tank/backups` empty, `tank/iso`, `tank/templates` |
| NFS exports | `/tank/media` and `/tank/data`, `rw,sync,no_root_squash` to `192.168.1.0/24` |

`ZFS.md` justifies RAIDZ1 with "regular backups to external/cloud". Those do not exist.
It also states "nothing on fastpool is unique", which stopped being true when Immich's
Postgres and Karakeep's data landed on `local-path` on `k8s-worker-1`.

## Rules

- Snapshots on `tank/media` and `tank/data` are mandatory before calling anything on the
  NAS "backed up".
- Offsite copies read from a snapshot, never from the live mount.
- `no_root_squash` plus no snapshots means any LAN device can wipe the NAS irrecoverably.
  Snapshots fix the second half; `root_squash` is tracked in the personal TODO.

## Planned

sanoid for snapshots (hourly 24 / daily 14 / monthly 3 on `tank/media` and `tank/data`,
daily 7 on `fastpool/vm-disks`), then restic from the newest snapshot to Scaleway. Both
in Ansible under `ansible/playbooks/proxmox-*.yaml`. See
[../tools/zfs-snapshots-sanoid.md](../tools/zfs-snapshots-sanoid.md) and
[../tools/restic-rclone.md](../tools/restic-rclone.md).

## Restore

- Undo a deletion: `ls /tank/media/.zfs/snapshot/`, `cp` the file back, or
  `zfs rollback tank/media@<snap>` for the whole dataset (destroys later changes).
- Pool lost: rebuild pool with `make proxmox-zfs`, then restore file-level from restic.
