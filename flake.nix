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

      packages.${system} = {
        default = pkgs.callPackage ./package.nix { };
        disk-startup-notify = pkgs.callPackage ./package.nix { };
      };

      overlays.default = final: prev: {
        disk-startup-notify = prev.callPackage ./package.nix { };
      };
    };
}
