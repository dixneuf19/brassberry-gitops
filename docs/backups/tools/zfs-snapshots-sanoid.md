# ZFS snapshots with sanoid (candidate)

Status: **not deployed**. Zero snapshots exist on `jonbonas` today.

## What it would do

sanoid takes and prunes snapshots per dataset from a policy file. Snapshots are the
undo button for everything on the NAS and the consistent source for the offsite copy.
syncoid (same package) replicates snapshots to another pool or host; not needed until a
second ZFS box exists.

## Proposed policy (`/etc/sanoid/sanoid.conf`)

| Dataset | hourly | daily | monthly | Why |
|---|---|---|---|---|
| `tank/media` (Immich library + dumps) | 24 | 14 | 3 | photos, class A |
| `tank/data` (`nfs-jonbonas` PVCs, Karakeep tarballs, ad-hoc backups) | 24 | 14 | 3 | class A and B |
| `fastpool/vm-disks` (k8s-worker-1 zvol) | 0 | 7 | 0 | undo a bad node upgrade |
| `tank/iso`, `tank/templates`, `tank/backups` | 0 | 0 | 0 | rebuildable or already a backup |

Snapshots of a zvol under a running VM are crash-consistent, fine for a k8s node whose
databases have their own backups.

## Deployment (Ansible, `ansible/playbooks/proxmox-sanoid.yaml`)

1. `apt install sanoid` (Debian package ships `sanoid.timer`, runs every 15 min).
2. Template the config above, `recursive = no`, `autoprune = yes`.
3. Enable `sanoid.timer`.
4. Verify: `zfs list -t snapshot -o name,used,creation | tail`.

Also worth adding in the same playbook: `zfs-zed` mail or a webhook so a degraded pool
is noticed, since RAIDZ1 gives exactly one chance.

## Space

Snapshots cost the delta. Immich originals are write-once, so 14 dailies of `tank/media`
cost roughly the photos added in two weeks. `tank/data` churns more (Karakeep tarballs
are ~400M/day), still under 10G for the policy above.

## Restore

- One file: copy from `/tank/media/.zfs/snapshot/autosnap_<stamp>_daily/immich/...`.
- Whole dataset: `zfs rollback -r tank/media@autosnap_<stamp>_daily` (destroys newer
  snapshots and data, stop NFS clients first).

## Reference

https://blog.hofstede.it/my-multi-stage-backup-strategy-zfs-proxmox-and-paranoia/
(sanoid + Proxmox + offsite, same stack as here).
