## ADDED Requirements

### Requirement: Tailscale policy is code
The tailnet policy SHALL be managed by `terraform/cloud` as `tailscale_acl`, starting from an import of the current console policy with no change.

#### Scenario: Import
- **WHEN** the import is planned
- **THEN** the plan shows the import and no change to the policy

#### Scenario: Invalid policy
- **WHEN** a merged change produces a policy that Tailscale rejects or whose tests fail
- **THEN** the cloud apply fails and the previous policy stays in force

### Requirement: devbox has its own tag
devbox SHALL join the tailnet as `tag:devbox`, owned by `tag:brassberry` so the existing Terraform OAuth client can mint its keys.

#### Scenario: Tag on join
- **WHEN** devbox joins the tailnet
- **THEN** `tailscale status` lists it as `devbox` tagged `tag:devbox`, with no key expiry

### Requirement: devbox grants
The policy SHALL allow `group:admin` to reach `tag:devbox` on TCP 443 and 22, allow `tag:devbox` to reach `tag:brassberry` on TCP 22, 6443 and 8006, and allow nothing else to or from `tag:devbox` inside the tailnet. The policy `tests` SHALL assert these grants.

#### Scenario: Admin reaches devbox
- **WHEN** a device of `dixneuf19@github` connects to devbox on 443 or 22
- **THEN** the connection is allowed

#### Scenario: devbox reaches cluster admin ports
- **WHEN** a process on devbox connects to a `tag:brassberry` node on 22 or 6443
- **THEN** the connection is allowed

#### Scenario: devbox blocked on other ports
- **WHEN** a process on devbox connects to a `tag:brassberry` node on 80
- **THEN** the connection is refused

#### Scenario: Cluster cannot reach devbox
- **WHEN** a `tag:brassberry` node connects to devbox on any port
- **THEN** the connection is refused

### Requirement: Auth key flows from Terraform
`terraform/cloud` SHALL mint a single-use, preauthorized auth key for `tag:devbox` and expose it as a sensitive output. `terraform/proxmox` SHALL read it through `terraform_remote_state` and deliver it to devbox through cloud-init, without needing Tailscale credentials itself.

#### Scenario: Key consumed
- **WHEN** devbox has joined and the cloud layer later mints a new key
- **THEN** the next proxmox plan does not replace devbox

#### Scenario: Local proxmox apply
- **WHEN** I run `terraform apply` in `terraform/proxmox` with only S3 and Proxmox credentials
- **THEN** the apply reads the key and succeeds
