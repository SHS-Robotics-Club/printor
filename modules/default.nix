{inputs, ...}: {
  imports = [
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.sd-image
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.core
    ./orcaslicer.nix
    ./nginx.nix
  ];

  users = {
    users = {
      # User for orcaslicer services
      printman = {
        isNormalUser = true;
        createHome = true;
      };
      # Administrative user
      sc = {
        isNormalUser = true;
        hashedPassword = "$y$j9T$EadXuwn3fN97sHqIT734U1$Lw9ovopcJ8iPKlSot5eSOSid/SIwF273px8jZNNYfe1";
        extraGroups = ["wheel"];
      };
    };
  };

  # Create $XDG_CONFIG_HOME so orcaslicer runs
  systemd.tmpfiles.rules = [
    "d /home/printman/.config 0750 printman users"
  ];

  # Enable sshd and open port 22
  services = {
    openssh = {
      enable = true;
      openFirewall = true;
    };
  };

  nixpkgs = {
    hostPlatform = "aarch64-linux";
  };

  system.stateVersion = "25.05";
}
