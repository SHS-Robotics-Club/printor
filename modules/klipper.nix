{
  lib,
  pkgs,
  ...
}: let
  # Printers are defined as printer-name = ./path/to/config;
  printers = {
    printer1 = ./configs/printer1/printer.cfg;
    printer2 = ./configs/printer2/printer.cfg;
  };
in {
  environment.systemPackages = [pkgs.klipper];
  systemd = {
    services =
      {
        # Klipper template unit
        "klipper@" = {
          description = "Klipper 3D Printer Firmware - %i";
          after = ["network.target"];

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            SupplementaryGroups = "dialout";
            StateDirectory = "klipper-%i";
            RuntimeDirectory = "klipper-%i";
            WorkingDirectory = "${pkgs.klipper}/lib";
            ExecStart = "${pkgs.klipper}/bin/klippy /var/lib/klipper-%i/printer.cfg";
            Restart = "always";
            RestartSec = 10;
          };
        };

        # Moonraker template unit
        "moonraker@" = {
        };
      }
      // lib.mapAttrs' (printerName: _configFile:
        lib.nameValuePair "klipper@${printerName}" {
          wantedBy = ["multi-user.target"];
          overrideStrategy = "asDropin";
        })
      printers;
    # Enable service template unit for each definition in printers

    # Copy each printer.cfg to the from the nix store to /var/lib so it is writeable by klipper
    tmpfiles.rules = lib.mapAttrsToList (printerName: configFile: "C /var/lib/klipper-${printerName}/printer.cfg - - - - ${configFile}") printers;
  };

  services = {
    udev.extraRules = ''
      SUBSYSTEM=="tty", ATTRS{id_vendor}=="Klipper", MODE="0660", GROUP="dialout"
    '';
    # mainsail = {
    #   enable = true;
    # };
  };
}
