## ADDED Requirements

### Requirement: devbox is created from the NixOS base image
`terraform/proxmox` SHALL create devbox as Proxmox VM 210 on jonbonas, booted from a pinned release of the NixOS base image, with hostname `devbox`, address `192.168.1.50/24` and gateway `192.168.1.254` set through cloud-init.

#### Scenario: First creation
- **WHEN** `terraform apply` runs in `terraform/proxmox` and devbox does not exist
- **THEN** the VM boots NixOS, takes hostname `devbox` and address `192.168.1.50`, and joins the tailnet as `tag:devbox`

#### Scenario: New base image release
- **WHEN** the pinned base image release changes in Terraform while devbox exists
- **THEN** the plan does not replace devbox

### Requirement: devbox converges to main
devbox SHALL build `nixosConfigurations.devbox` from `github:dixneuf19/brassberry-gitops?dir=nixos` on `main` within 15 minutes of a merge, and within 2 minutes of boot, and switch to it without rebooting.

#### Scenario: Config change merged
- **WHEN** a PR changing `nixos/hosts/devbox/` is merged
- **THEN** devbox runs the new generation within 15 minutes and open Rex sessions keep running

#### Scenario: First boot
- **WHEN** devbox boots from the generic base image for the first time
- **THEN** it switches to `nixosConfigurations.devbox` within 2 minutes

#### Scenario: Broken config on main
- **WHEN** `main` holds a devbox config that fails to build
- **THEN** devbox keeps running its current generation and the upgrade unit reports a failure

### Requirement: devbox can be rolled back
devbox SHALL keep at least 10 previous generations, selectable with `nixos-rebuild switch --rollback` or from the boot menu.

#### Scenario: Bad generation
- **WHEN** a new generation breaks Rex or Tailscale
- **THEN** I can return to the previous generation over LAN SSH or from the Proxmox console

### Requirement: Rex login server
devbox SHALL run the Rex login server from the Rex `preview` channel, reachable at `https://devbox.tail960f.ts.net` through Tailscale Serve, mapping `tailscale:dixneuf19@github` to account `dixneuf19` by default and to `root` on request.

#### Scenario: Default account
- **WHEN** I run `rex -S devbox ls` from my Mac
- **THEN** the connection is served by a Rex server running as `dixneuf19`

#### Scenario: Root account
- **WHEN** I connect to `https://root@devbox.tail960f.ts.net`
- **THEN** the connection is served by a Rex server running as `root`

#### Scenario: Unknown caller
- **WHEN** a tailnet identity other than `dixneuf19@github` connects
- **THEN** the login server refuses it

#### Scenario: Rex upgrade
- **WHEN** a new Rex version is deployed
- **THEN** account servers and their sessions keep running

### Requirement: SSH access
devbox SHALL accept OpenSSH logins as `dixneuf19` with my public key only, with password and root logins disabled.

#### Scenario: Key login
- **WHEN** I run `ssh dixneuf19@devbox.tail960f.ts.net`
- **THEN** the login succeeds with my key and no password prompt

#### Scenario: Password login
- **WHEN** anyone attempts a password login
- **THEN** sshd refuses it
