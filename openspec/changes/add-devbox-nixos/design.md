## Context

- jonbonas runs Proxmox. `terraform/proxmox` creates VMs from the Ubuntu cloud image, and `k8s-worker-1` is configured by Ansible on top. The proxmox layer has `autoApply: false` in Burrito and is applied by hand.
- Every host is on the tailnet `tail960f.ts.net`. The Pis and `oracle-arm` are `tag:brassberry`; PR #1819 tags jonbonas and `k8s-worker-1` the same way. The policy lives only in the admin console. As described in #1819 it holds `group:admin -> *:*` and `tag:brassberry -> tag:brassberry:*`.
- `terraform/cloud` owns the Tailscale provider (OAuth client scoped to `tag:brassberry`) and is auto-applied by Burrito. `oracle-arm` already gets a Terraform-minted key through cloud-init.
- Renovate opens most PRs in the repo and auto-merges minor and patch bumps.
- My Mac is MDM-managed without sudo and has no Nix. It cannot build `x86_64-linux` systems.
- Rex ships a flake with a NixOS module (`services.rex.loginServer`, with `accounts`, `defaults` and `tailscaleServe`) on `stable`, `preview` and `snapshot` channels. `stable` has no release yet.

## Goals / Non-Goals

**Goals:**
- A NixOS VM, `devbox`, running the Rex login server as my account, reachable over the tailnet.
- Every change to devbox goes through a PR. Nothing is configured by hand on the VM.
- Tailscale access rules for devbox are code, least privilege, and tested.
- No Nix needed on the Mac.

**Non-Goals:**
- Other services on devbox. The layout leaves room for them.
- Monitoring devbox. It would need a `tag:brassberry -> tag:devbox:9100` grant.
- Tailscale SSH.
- Secrets for future services (sops-nix, agenix).
- Backups of devbox's `/home`.

## Decisions

### NixOS over Ubuntu with Ansible or cloud-init
The Rex module generates the systemd unit, the accounts file and the `tailscale serve` setup. PR #1891 copied those by hand from the docs, and they were its riskiest part. The Nix store makes the system read-only and versioned: each config is one generation, switches are atomic, and rollback is a previous generation. This is also the first step toward more Nix in the homelab.

Alternatives: Ubuntu with Ansible (#1891) works but drifts and has no rollback. Ubuntu with cloud-init only runs once, so any later change means editing the VM by hand or recreating it.

### Pull-based deploys with `system.autoUpgrade`
devbox builds `github:dixneuf19/brassberry-gitops?dir=nixos#devbox` from `main` every 15 minutes and 2 minutes after boot. The attribute comes from the hostname, so one generic image serves every future NixOS host. `allowReboot = false`, because Rex sessions matter more than applying kernel updates right away.

Alternatives: push from Terraform with the nixos-anywhere module needs Nix wherever Terraform runs. Push with deploy-rs or colmena is manual and adds a tool. Pull matches ArgoCD for the cluster: merge, then converge.

### Base image built in CI, VM updated in place
`.github/workflows/nixos.yaml` builds a qcow2 with nixpkgs' image builder and publishes it as a release. Terraform downloads it with a pinned checksum, as it does for the Ubuntu image. Creation is reproducible, and changes after creation arrive through `autoUpgrade`.

Alternatives: nixos-infect turns a running Ubuntu into NixOS on first boot. It is a one-shot mutation with Ubuntu leftovers, and a half-converted VM if it fails. A manual ISO install is not reproducible. Replacing the VM on every change would kill Rex sessions and require a separate data disk.

### cloud-init for per-VM data only
Cloud-init sets the hostname, the static IP and the Tailscale key file. Terraform stays the source of truth for VM addresses, as for `k8s-worker-1`. Users, SSH keys, services and packages live in Nix. My public SSH key goes in `base.nix`, because public keys are fine in git and that makes them declarative.

### New `tag:devbox` instead of `tag:brassberry`
A tagged node's traffic is governed by its tag, not by the user logged into it. With `tag:brassberry`, devbox would be fully meshed with the cluster in both directions. `tag:devbox` gets exactly the grants below. `tagOwners` makes `tag:brassberry` the owner of `tag:devbox`, the pattern the Tailscale Kubernetes operator uses, so the existing OAuth client can mint devbox keys without a new client.

```jsonc
"tagOwners": {
  "tag:devbox": ["tag:brassberry"],
},
"grants": [
  { "src": ["group:admin"], "dst": ["tag:devbox"], "ip": ["tcp:443", "tcp:22"] },
  { "src": ["tag:devbox"], "dst": ["tag:brassberry"], "ip": ["tcp:22", "tcp:6443", "tcp:8006"] },
],
"tests": [
  { "src": "dixneuf19@github", "accept": ["tag:devbox:443", "tag:devbox:22"] },
  { "src": "tag:devbox", "accept": ["tag:brassberry:22", "tag:brassberry:6443"], "deny": ["tag:brassberry:80"] },
  { "src": "tag:brassberry", "deny": ["tag:devbox:22", "tag:devbox:443"] },
],
```

Rex identifies callers through Tailscale Serve, which only identifies user-owned devices. A tagged node cannot log in to Rex even if a grant let it reach port 443.

### Policy as code in `terraform/cloud`
`tailscale_acl` lives next to the existing Tailscale provider. Phase 1 imports the console policy unchanged (`import { id = "acl" }`), and later changes are reviewed diffs. Burrito auto-applies the cloud layer, so the policy `tests` act as the safety net: Tailscale rejects a policy whose tests fail.

Alternative: keep the console and paste snippets. That is faster, but RBAC stays out of git.

### Auth key minted in `terraform/cloud`, read by `terraform/proxmox`
`tailscale_tailnet_key.devbox`: `tags = ["tag:devbox"]`, `preauthorized = true`, `reusable = false`, `recreate_if_invalid = "always"`, `depends_on = [tailscale_acl.this]`, exported as a sensitive output. `terraform/proxmox` reads it with `terraform_remote_state`, like `terraform/github` reads `terraform/bitwarden`. Cloud-init writes it to `/var/lib/tailscale/authkey` (0600), and `services.tailscale.authKeyFile` points at it. The VM ignores changes to `initialization`, so a new key never replaces devbox.

Alternatives: the Tailscale provider in `terraform/proxmox` would need `TAILSCALE_OAUTH_*` on every local proxmox apply. A Bitwarden secret fetched by the VM needs a machine token on the VM, which is more plumbing than one first-boot key needs.

### Rex login server, `preview` channel
The login server runs my sessions as `dixneuf19` (default) or `root` (on request), reuses the VM's tailnet node through Serve, and keeps account servers running across Rex upgrades. `preview` because `stable` has no release yet. Moving to `stable` is a one-line change to the flake input.

Alternatives: a personal server with built-in Tailscale adds a second tailnet node and loses sessions on upgrade. A shared server runs everything as a `rex` system account.

### Renovate for `flake.lock`
Renovate already handles the repo's bumps, so its `nix` manager with `lockFileMaintenance` (weekly, grouped `nixos`, no automerge) keeps one bot and one dashboard. If Renovate cannot run `nix flake update` here, the fallback is `DeterminateSystems/update-flake-lock` weekly, with `nixos/flake.lock` excluded from Renovate. Running both would open competing PRs on the same file.

### Layout

```
nixos/
  flake.nix              inputs: nixpkgs (stable), rex (preview tarball)
  flake.lock
  modules/base.nix       user, sshd, qemu agent, cloud-init, tailscale, autoUpgrade, nix gc, firewall
  modules/image.nix      qcow2 settings, root partition grows on boot
  hosts/devbox/default.nix
.github/workflows/nixos.yaml
terraform/cloud/tailscale.tf        tailscale_acl, tailnet key, output
terraform/proxmox/devbox.tf         image download, VM, cloud-init snippet
terraform/proxmox/remote_state.tf
renovate.json
```

## Risks / Trade-offs

- [Broken config merged to `main`] -> CI builds the devbox toplevel on every PR. If one slips through, `nixos-upgrade` fails and devbox keeps the running generation.
- [Bad generation breaks Tailscale, so devbox drops off the tailnet] -> Rollback over LAN SSH (`192.168.1.50`) or from the boot menu in the Proxmox console. 10 generations are kept.
- [Policy import differs from the console] -> Phase 1 is its own PR, merged only when the plan shows no change. Burrito applies it.
- [Auto-applied policy change locks me out] -> Policy `tests` assert admin access. Tailscale rejects a policy whose tests fail, and the old one stays.
- [OAuth client cannot gain the `policy_file` scope] -> Create a new client and rotate `TAILSCALE_OAUTH_*` where Burrito and direnv read them.
- [Key spent or expired before devbox first boots] -> Apply `terraform/cloud` to mint a fresh one, then recreate devbox.
- [Key left in the cloud-init snippet on jonbonas and in Terraform state] -> The key is single-use and spent at first boot.
- [devbox builds on itself, using CPU and disk on jonbonas] -> Mostly binary cache downloads. Weekly `nix.gc` keeps the store bounded.
- [Recreating devbox loses `/home` and the tailnet node] -> Recreation only happens for sizing or a new base image. Backups are out of scope.
- [Rex `preview` channel breaks] -> Pin to the previous lock with a revert PR. The lock records the exact release.

## Migration Plan

Each phase is its own PR.

1. **Policy as code.** Add the `policy_file` scope, import the current policy into `terraform/cloud` unchanged.
2. **`tag:devbox`.** tagOwners, grants, tests, the tailnet key and its output.
3. **NixOS flake and CI.** `nixos/`, the workflow, the Renovate change. The first `main` build publishes the base image.
4. **devbox VM.** Remote state, image download, VM and cloud-init in `terraform/proxmox`, applied by hand.
5. **Cleanup.** Close PR #1891 and delete its branch.

Rollback: destroy the devbox VM, revert the phase 2 PR (the tag and grants), and leave the imported policy in place.

## Open Questions

- What is the exact content of the current console policy, including `group:admin` membership?
- Can the existing OAuth client gain the `policy_file` scope, or does it need replacing?
- Can Renovate run `nix flake update` in this setup?
- What is the right nixpkgs attribute for the qcow2 image builder on the chosen nixpkgs release, and does the bpg provider accept the asset name and content type for download?
