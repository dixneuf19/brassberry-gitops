{
  description = "NixOS hosts of the brassberry homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Only for fast-moving agent CLIs; the system itself stays on stable
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      rex,
    }:
    let
      system = "x86_64-linux";
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "claude-code";
      };
      mkHost =
        modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit pkgsUnstable; };
          modules = [ ./modules/base.nix ] ++ modules;
        };
    in
    {
      nixosConfigurations = {
        # Generic system baked into the base image; a VM switches to its own host
        # config (attribute = hostname) on first boot
        base = mkHost [ ];

        devbox = mkHost [
          rex.nixosModules.default
          ./hosts/devbox
        ];
      };

      packages.${system}.base-image = self.nixosConfigurations.base.config.system.build.images.qemu-efi;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}
