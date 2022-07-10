# fix-ssh-on-pi

## Scripts

### fix-ssh-on-pi (to rename)

Configuration: `fix-ssh-on-pi.ini`

Then run `sudo fix-ssh-on-pi.bash`, it creates an image that you can burn on the SD card (with _balenaEtcher_ for example).

## Playbooks

Configuration: `hosts.yaml`.

You can run the playbooks in this order:

- `ping.yaml` to check host connectivity
- `kernel-modules.yaml` to install module needed for k0s
- `upgrade.yaml` to update the hosts
- `mounts.yaml` for the disks
- `nfs-server.yaml` to install nfs

A convenient Makefile is setup, for example you can simply run `make ping`.

To run all of these playbooks in order, run `make all`.

## K0s

```bash
k0sctl apply --config k0sctl.yaml
```
