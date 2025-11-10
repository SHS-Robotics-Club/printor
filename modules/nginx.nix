{pkgs, ...}: {
  services = {
    nginx = {
      enable = true;
      virtualHosts.localhost = {
        locations = {
          "/slice/websockify" = {
            proxyPass = "http://127.0.0.1:6080";
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
              proxy_read_timeout 61s;
              proxy_buffering off;
            '';
          };

          "/slice" = {
            return = "301 /slice/";
          };

          "/slice/" = {
            extraConfig = ''
              alias ${pkgs.novnc}/share/webapps/novnc/;
              index vnc.html;
              try_files $uri $uri/ /vnc.html;
            '';
          };
        };
      };
    };
  };
}
