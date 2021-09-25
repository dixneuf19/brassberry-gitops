# fix-ssh-on-pi

## Scripts

### fix-ssh-on-pi (to rename)

Configuration: `fix-ssh-on-pi.ini`

Then run `sudo fix-ssh-on-pi.bash`, it creates an image that you can burn on the SD card (with _balenaEtcher_ for example).

## Playbooks

Configuration: `pie_hosts.yaml` (or `pie_hosts_remote.yaml`)

You can run the playbooks in this order:

- `ping-example-playbook.yaml` to check host connectivity
- `kerner-modules.yaml` to install module needed for k0s
- `upgrade-playbook.yaml` to update the hosts
- `mounts.yaml` for the disks
- `nfs-server-playbook.yaml` to install nfs

## K0s

```bash
k0sctl apply --config k0sctl.yaml
```
