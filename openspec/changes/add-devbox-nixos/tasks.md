## 1. Policy as code (PR 1, terraform/cloud)

- [x] 1.1 Confirm the Terraform OAuth client has the `policy_file` scope
- [x] 1.2 Save the current console policy verbatim to `terraform/cloud/tailscale-policy.hujson`
- [x] 1.3 Add `tailscale_acl.this` reading that file, with an `import { id = "acl" }` block
- [x] 1.4 `terraform plan` in `terraform/cloud` shows one import and no policy change

## 2. tag:devbox (PR 2, terraform/cloud, stacked on PR 1)

- [x] 2.1 Add `tag:devbox` to `tagOwners`, owned by `autogroup:admin` and `tag:terraform`; the Terraform OAuth client carries only `tag:terraform` (admin console)
- [x] 2.2 Add the `tag:devbox -> tag:brassberry:22,6443,8006` rule
- [x] 2.3 Add policy `tests` for admin to devbox, devbox to cluster (allowed and denied ports), and cluster to devbox
- [x] 2.4 Add `tailscale_tailnet_key.devbox` (single use, preauthorized, `tag:devbox`) and the sensitive output `devbox_tailscale_auth_key`
- [x] 2.5 `terraform plan` shows the policy diff and one new key, nothing else

## 3. NixOS flake and CI (PR 3, independent of PR 1 and 2)

- [x] 3.1 `nixos/flake.nix` with nixpkgs stable and the Rex `preview` tarball as inputs, exposing `nixosConfigurations.devbox` and `packages.x86_64-linux.base-image`
- [x] 3.2 `nixos/modules/base.nix`: user, sshd, qemu agent, cloud-init, tailscale with `authKeyFile`, `autoUpgrade`, nix gc, firewall
- [x] 3.3 Base image from the nixpkgs `qemu-efi` variant (no separate module needed), zstd-compressed in CI because release assets cap at 2 GiB
- [x] 3.4 `nixos/hosts/devbox/default.nix`: hostname and Rex login server
- [x] 3.5 Generate `nixos/flake.lock` and evaluate the devbox config in a Nix container
- [x] 3.6 `.github/workflows/nixos.yaml`: flake check and devbox build on PRs; image build and release on `main`
- [x] 3.7 Renovate: enable the `nix` manager with weekly `lockFileMaintenance` for `nixos/`, grouped `nixos`, no automerge
- [ ] 3.8 CI green on the PR

## 4. devbox VM (PR 4, terraform/proxmox, after PR 2 is applied and PR 3 has published an image)

- [x] 4.1 `terraform/proxmox/remote_state.tf` reading `cloud/terraform.tfstate`
- [x] 4.2 Download the pinned `nixos-base-*` release to jonbonas, with checksum
- [x] 4.3 cloud-init user-data snippet: hostname and the Tailscale key file
- [x] 4.4 `proxmox_virtual_environment_vm.devbox` (VM 210, `192.168.1.50`, 4 cores, 8 GiB, 64 GiB), ignoring `disk[0].file_id` and `initialization`
- [ ] 4.5 Set `nixos_base_release` and `nixos_base_sha256` in `devbox.tf` from the first release, then `terraform plan` shows the image, the snippet and the VM (plus the existing Ubuntu image and `k8s-worker-1` gateway drift)

## 5. Rollout and verification (manual)

- [ ] 5.1 Merge PR 1, check Burrito applied it and the console policy kept its comments
- [ ] 5.2 Merge PR 2, check the policy tests pass and the key exists
- [ ] 5.3 Merge PR 3, check the `nixos-base-*` release
- [ ] 5.4 Merge PR 4 and `terraform apply` in `terraform/proxmox`
- [ ] 5.5 `tailscale status` lists `devbox` tagged `tag:devbox`; `ssh devbox` works
- [ ] 5.6 `rex hosts add devbox devbox.tail960f.ts.net` (a bare name tries 443, then 7297), then `rex -S devbox ls` runs as `dixneuf19`
- [ ] 5.7 From a devbox session, `ssh brassberry-24` works and `curl brassberry-24:80` is refused
- [ ] 5.8 Merge a trivial change to `nixos/hosts/devbox/` and see the new generation within 15 minutes while a Rex session stays open

## 6. Cleanup

- [ ] 6.1 Close PR #1891 and delete branch `feat/rex-login-server`
- [ ] 6.2 Archive the OpenSpec change
