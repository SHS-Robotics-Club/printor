{inputs, ...}: {
  imports = [
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.sd-image
    inputs.nixos-rk3588.nixosModules.boards.orangepi5.core
    ./klipper.nix
    # ./orcaslicer.nix
    # ./nginx.nix
  ];

  # Administrative user
  users = {
    users = {
      sc = {
        isNormalUser = true;
        hashedPassword = "$y$j9T$vCBf5Z4RBPNmGHaU5lbJS/$/0k7JPhfaC3KDF7COdu6ghLW1l3kNsepGqhqZ.KYIq4";
        extraGroups = ["wheel"];
      };
    };
  };

  # Enable sshd and open port 22
  services = {
    openssh = {
      enable = true;
      openFirewall = true;
    };
  };

  networking.firewall.allowedTCPPorts = [80];

  nixpkgs = {
    hostPlatform = "aarch64-linux";
  };

  system.stateVersion = "25.05";
}
