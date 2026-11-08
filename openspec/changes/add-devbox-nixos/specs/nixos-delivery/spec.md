## ADDED Requirements

### Requirement: Flake is checked on every change
A GitHub Actions workflow SHALL run `nix flake check` and build `nixosConfigurations.devbox.config.system.build.toplevel` on every PR and push that touches `nixos/`.

#### Scenario: Config that does not build
- **WHEN** a PR introduces a devbox config that fails to evaluate or build
- **THEN** the workflow fails on the PR

### Requirement: Base image is published
On `main`, when `nixos/modules/` or `nixos/flake.lock` change, the workflow SHALL build the base image as a qcow2 and publish it as GitHub release `nixos-base-<short sha>`. The image SHALL contain no host-specific config and no secret.

#### Scenario: Base module change merged
- **WHEN** a change to `nixos/modules/base.nix` is merged
- **THEN** a new `nixos-base-<short sha>` release holds the image and its checksum

#### Scenario: Host-only change merged
- **WHEN** only `nixos/hosts/` changes on `main`
- **THEN** no image is published

### Requirement: Lock file bumps
`nixos/flake.lock` SHALL be bumped weekly by exactly one bot, through a PR that is never auto-merged.

#### Scenario: Weekly bump
- **WHEN** nixpkgs or Rex have newer revisions
- **THEN** one PR updates `nixos/flake.lock` and waits for my merge
