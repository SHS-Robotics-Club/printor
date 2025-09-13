{inputs, ...}: {
  imports = [
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.sd-image
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.core
  ];

  ff = {
    userConfig = {
      users.user = {
        hashedPassword = "$6$i8pqqPIplhh3zxt1$bUH178Go8y5y6HeWKIlyjMUklE2x/8Vy9d3KiCD1WN61EtHlrpWrGJxphqu7kB6AERg6sphGLonDeJvS/WC730";
      };
    };
  };

  users.allowNoPasswordLogin = true;

  nixpkgs = {
    hostPlatform = "aarch64-linux";
    config.allowUnfree = true;
  };

  system.stateVersion = "25.05";
}
