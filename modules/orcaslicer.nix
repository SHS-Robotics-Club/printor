# commented stuff broken pls fix, maybe just actually need websockify/novnc
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    novnc
    orca-slicer
    python3Packages.websockify
    tigervnc
  ];

  systemd.services = {
    websockify = {
      description = "Websockify VNC Bridge";
      after = ["orcaslicer-vnc.service"];
      requires = ["orcaslicer-vnc.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 5;

        ExecStart = ''
          ${pkgs.python3Packages.websockify}/bin/websockify \
            --heartbeat=30 \
            127.0.0.1:6080 localhost:5901
        '';
      };
    };
    orcaslicer-vnc = {
      description = "OrcaSlicer VNC Service";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        User = "printman";
        Group = "users";
        Type = "simple";
        Environment = ["DISPLAY=:1"];
        Restart = "on-failure";
        RestartSec = 5;

        ExecStart = ''
          ${pkgs.tigervnc}/bin/Xvnc :1 \
            -geometry 1920x1080 \
            -depth 16 \
            -SecurityTypes None \
            -AlwaysShared \
            -AcceptKeyEvents \
            -AcceptPointerEvents \
            -AcceptCutText \
            -SendCutText \
            -fp ${pkgs.xorg.fontmiscmisc}/lib/X11/fonts/misc/
        '';
      };
    };

    orcaslicer-app = {
      description = "OrcaSlicer Application";
      after = ["orcaslicer-vnc.service"];
      requires = ["orcaslicer-vnc.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        User = "printman";
        Group = "users";
        Type = "simple";
        Environment = ["DISPLAY=:1"];
        Restart = "on-failure";

        ExecStart = "${pkgs.orca-slicer}/bin/orca-slicer";
      };
    };
  };
}
