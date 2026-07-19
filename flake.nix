{
  description = "Disk usage notification on i3 login with optional cleanup";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosModules.default = import ./module.nix;

      packages.${system} =
        let
          pkg = pkgs.callPackage ./package.nix { };
        in
        {
          inherit (pkg) diskCleanupRoot diskCleanup diskStartupNotify;
          default = pkg.diskStartupNotify;
        };

      overlays.default = final: prev: {
        disk-startup-notify = (prev.callPackage ./package.nix { }).diskStartupNotify;
      };
    };
}
