## Why

I want a Rex server in the homelab that my devices reach over the tailnet, with sessions that run as my own account and survive config changes and Rex upgrades. It is also the first NixOS host, a low-stakes place to start using Nix. PR #1891 did the same on Ubuntu with Ansible, and this change replaces it.

## What Changes

- New NixOS VM `devbox` on jonbonas (Proxmox VM 210, `192.168.1.50`), created by `terraform/proxmox` from a NixOS base image built in GitHub Actions.
- New `nixos/` flake holding a shared base module and the `devbox` host config. devbox pulls `main` and switches to it atomically (`system.autoUpgrade`).
- devbox runs the Rex login server through the Rex NixOS module, reached at `https://devbox.tail960f.ts.net:7297` through Tailscale Serve.
- The Tailscale policy moves from the admin console into `terraform/cloud` (`tailscale_acl`), imported unchanged first, with policy tests.
- New `tag:devbox`, with grants: me to devbox on 7297 (Rex) and 22; devbox to cluster nodes on 22, 6443 and 8006; nothing from the cluster to devbox.
- `terraform/cloud` mints the devbox Tailscale auth key, and `terraform/proxmox` reads it through remote state.
- New GitHub Actions workflow builds the flake on PRs and publishes the base image on `main`.
- Renovate bumps `nixos/flake.lock`.
- PR #1891 is closed.

## Capabilities

### New Capabilities

- `devbox-host`: the devbox VM, its NixOS configuration, how it is created and how it applies changes, and the Rex login server it runs.
- `nixos-delivery`: CI checks on the flake, the base image release, and dependency bumps for `nixos/flake.lock`.
- `tailnet-policy`: the Tailscale policy as code, `tag:devbox` and its grants, and the auth key flow from Terraform to the VM.

### Modified Capabilities

None. `openspec/specs/` is empty.

## Impact

- **Terraform:** `terraform/cloud` gains `tailscale_acl`, a tailnet key and an output, and is auto-applied by Burrito. `terraform/proxmox` gains a remote state, an image download and a VM, and is applied by hand.
- **Tailscale:** the OAuth client used by Terraform already has the `policy_file` scope. After the import, every policy change goes through a PR.
- **CI:** new workflow with a Nix installer and cache.
- **Renovate:** `nix` manager enabled.
- **jonbonas:** one more VM on fastpool (4 cores, 8 GiB, 64 GiB).
- **New tooling:** Nix enters the repo. Nothing needs Nix on the Mac.
