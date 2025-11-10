{
  lib,
  pkgs,
  ...
}: let
  # Printer config directory relative to this file
  configDir = ../printerConfigs;

  # Filter ./config directory for directories containing a printer.cfg file, return a list
  printerNames = lib.attrNames (lib.filterAttrs (name: type: (type == "directory") && ((builtins.readDir "${configDir}/${name}") ? "printer.cfg")) (builtins.readDir configDir));

  # Take list of printer names as input, output attribute set containing printers and paths to their configs, auto generate moonraker config because it doesn't need to change per printer
  printers = lib.mergeAttrsList (lib.imap0 (i: printerName: {
      ${printerName} = {
        klipperCfg = "${configDir}/${printerName}";
        moonrakerCfg = mkMoonraker printerName (builtins.toString (7125 + i));
        port = 7125 + i;
      };
    })
    printerNames);

  # Template moonraker config
  mkMoonraker = printerName: port:
    pkgs.writeText "moonraker-${printerName}.conf" ''
      [server]
      host: 0.0.0.0
      port: ${port}
      klippy_uds_address: /run/klipper-${printerName}/klippy_uds

      [authorization]
      trusted_clients:
          10.0.0.0/24
          127.0.0.0/8
          169.254.0.0/16
          172.16.0.0/12
          192.168.0.0/16
          FC00::/7
          FE80::/10
          ::1/128
      cors_domains:
          *.lan
          *.local
          *://localhost
          *://localhost:*
          *://my.mainsail.xyz
          *://app.fluidd.xyz

      [history]

      [update_manager]
      enable_system_updates: False
    '';
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
            Restart = "always";
            RestartSec = 10;
          };
        };
      }
      # Enable klipper/moonraker service template unit for each definition in printers
      // lib.foldlAttrs (acc: printerName: configs:
        acc
        // {
          "klipper@${printerName}" = {
            wantedBy = ["multi-user.target"];
            overrideStrategy = "asDropin";
          };
          "moonraker@${printerName}" = {
            wantedBy = ["multi-user.target"];
            overrideStrategy = "asDropin";
            serviceConfig.ExecStart = "${lib.getExe pkgs.moonraker} -d /var/lib/data-${printerName} -c ${configs.moonrakerCfg}";
          };
        }) {}
      printers;

    # Create some directories and copy printer configs from the nix store to /var/lib so they are writeable by klipper
    tmpfiles.rules = let
      navi = pkgs.writeText "navi.json" (builtins.toJSON [
        {
          title = "Slicer";
          href = "/slice/";
          target = "_blank";
          position = "90";
        }
      ]);
    in
      lib.flatten (lib.mapAttrsToList (printerName: configs: [
          "d /var/lib/data-${printerName}/logs 0775 klipper klipper"
          "d /var/lib/data-${printerName}/systemd 0775 klipper klipper"
          "d /var/lib/data-${printerName}/comms 0775 klipper klipper"
          "C /var/lib/data-${printerName}/config 0775 klipper klipper - ${configs.klipperCfg}"
          "d /var/lib/data-${printerName}/config/.theme 0775 klipper klipper"
          "L+ /var/lib/data-${printerName}/config/.theme/navi.json 0775 klipper klipper - ${navi}"
        ])
        printers)
      ++ [
        "d /var/lib/data-printers-shared/gcodes 0775 klipper klipper"
      ];
  };

  fileSystems = lib.mapAttrs' (printerName: _:
    lib.nameValuePair "/var/lib/data-${printerName}/gcodes" {
      device = "/var/lib/data-printers-shared/gcodes";
      options = ["bind"];
    })
  printers;

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
        instances =
          lib.mapAttrsToList (_: config: {
            hostname = "localhost";
            inherit (config) port;
          })
          printers;
      });
    };
  };
}
