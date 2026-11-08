{
  description = "NixOS hosts of the brassberry homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rex,
    }:
    let
      system = "x86_64-linux";
      mkHost =
        modules:
        nixpkgs.lib.nixosSystem {
          inherit system;
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
