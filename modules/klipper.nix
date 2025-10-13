{
  lib,
  pkgs,
  ...
}: let
  # Printers are defined as printer-name = ./path/to/config;
  printers = {
    printer1 = ./testCT/printer.cfg;
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
            ExecStart = "${lib.getExe pkgs.klipper} /var/lib/klipper-%i/printer.cfg";
            Restart = "always";
            RestartSec = 10;
          };
        };

        # Moonraker template unit
        "moonraker@" = {
          description = "API Server for %i Klipper";
          after = ["network.target"];

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            StateDirectory = "moonraker-%i";
            RuntimeDirectory = "moonraker-%i";
            WorkingDirectory = "${pkgs.moonraker}/lib";
            ExecStart = "${lib.getExe pkgs.python3} ${pkgs.moonraker}/lib/moonraker/moonraker.py -d /var/lib/moonraker-%i -c /var/lib/moonraker-%i/moonraker.cfg";
            Restart = "always";
            RestartSec = 10;
          };
        };
      }
      # Enable service template unit for each definition in printers
      // lib.mapAttrs' (printerName: _configFile:
        lib.nameValuePair "klipper@${printerName}" {
          wantedBy = ["multi-user.target"];
          overrideStrategy = "asDropin";
        })
      printers;

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
