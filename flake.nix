{
  description = "printin' time";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux" # just so the formatter works
        "aarch64-linux"
      ];

      imports = [
        inputs.fpFmt.flakeModule
      ];

      flake.nixosImages.piprint = inputs.nixos-generators.nixosGenerate {
        system = "aarch64-linux";
        format = "sd-aarch64";
        specialArgs = {
          inherit inputs;
          rk3588 = {
            inherit (inputs) nixpkgs;
            pkgsKernel = import inputs.nixpkgs {
              localSystem = "x86_64-linux";
              crossSystem = "aarch64-linux";
            };
          };
        };
        modules = [
          ./configuration.nix
          inputs.ff.nixosModules.freedpomFlake
        ];
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    fpFmt = {
      url = "github:freedpom/FreedpomFormatter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ff = {
      url = "github:freedpom/FreedpomFlake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixos-rk3588.url = "github:gnull/nixos-rk3588";
  };
}
