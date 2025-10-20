{
  lib,
  pkgs,
  ...
}: let
  # Printers are defined as printer-name = ./path/to/config;
  printers = {
    printer1 = ./configs/printer1;
    printer2 = ./configs/printer2;
  };
in {
  environment.systemPackages = [pkgs.klipper pkgs.moonraker];

  # Create static users and groups for klipper and moonraker
  users = {
    users = {
      klipper = {
        isSystemUser = true;
        group = "klipper";
      };
      moonraker = {
        isSystemUser = true;
        group = "moonraker";
      };
    };
    groups = {
      klipper = {};
      moonraker = {};
    };
  };

  # Allow Moonraker to perform system-level operations
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.systemd1.manage-units" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.reboot-multiple-sessions")) &&
           subject.user == "moonraker") {
        return polkit.Result.YES;
      }
    });
  '';

  systemd = {
    services =
      {
        # Klipper template unit
        "klipper@" = {
          description = "Klipper 3D Printer Firmware - %i";
          after = ["network.target"];

          serviceConfig = {
            Type = "simple";
            User = "klipper";
            Group = "klipper";
            UMask = "002";
            SupplementaryGroups = "dialout";
            StateDirectory = "data-%i";
            RuntimeDirectory = "klipper-%i";
            WorkingDirectory = "${pkgs.klipper}/lib";
            ExecStart = "${lib.getExe pkgs.klipper} --api-server /run/klipper-%i/klippy_uds /var/lib/data-%i/config/printer.cfg";
            Restart = "always";
            RestartSec = 10;
          };
        };

        # Moonraker template unit
        "moonraker@" = {
          description = "API Server for %i Klipper";
          after = ["network.target"];

          path = [pkgs.iproute2];

          serviceConfig = {
            Type = "simple";
            User = "klipper";
            Group = "moonraker";
            SupplementaryGroups = "klipper";
            StateDirectory = "data-%i";
            RuntimeDirectory = "moonraker-%i";
            WorkingDirectory = "/var/lib/data-%i";
            ExecStart = "${lib.getExe pkgs.moonraker} -d /var/lib/data-%i -c /var/lib/data-%i/config/moonraker.conf";
            Restart = "always";
            RestartSec = 10;
          };
        };
      }
      # Enable klipper service template unit for each definition in printers
      // lib.mapAttrs' (printerName: _configFile:
        lib.nameValuePair "klipper@${printerName}" {
          wantedBy = ["multi-user.target"];
          overrideStrategy = "asDropin";
        })
      printers
      # Enable moonraker service template unit for each definition in printers
      // lib.mapAttrs' (printerName: _configFile:
        lib.nameValuePair "moonraker@${printerName}" {
          wantedBy = ["multi-user.target"];
          overrideStrategy = "asDropin";
        })
      printers;

    # Copy each printer.cfg to the from the nix store to /var/lib so it is writeable by klipper
    tmpfiles.rules = lib.flatten (lib.mapAttrsToList (printerName: configFile: [
        "d /var/lib/data-${printerName}/logs 0775 klipper klipper"
        "d /var/lib/data-${printerName}/gcodes 0775 klipper klipper"
        "d /var/lib/data-${printerName}/systemd 0775 klipper klipper"
        "d /var/lib/data-${printerName}/comms 0775 klipper klipper"
        "C /var/lib/data-${printerName}/config/printer.cfg 0775 klipper klipper - ${configFile}/klipper/printer.cfg"
        "C /var/lib/data-${printerName}/config/moonraker.conf 0775 moonraker moonraker - ${configFile}/moonraker/moonraker.conf"
      ])
      printers);
  };

  services = {
    # Ensure klipper has access to relevant serial devices
    udev.extraRules = ''
      SUBSYSTEM=="tty", ATTRS{id_vendor}=="Klipper", MODE="0660", GROUP="dialout"
    '';
    # Enable mainsail with fixed moonraker instances
    mainsail = {
      enable = true;
      nginx.locations."=/config.json".alias = pkgs.writeText "config.json" (builtins.toJSON {
        instancesDB = "json";
        instances = [
          {
            hostname = "localhost";
            port = "7125";
          }
          {
            hostname = "localhost";
            port = "7126";
          }
        ];
      });
    };
  };
}
