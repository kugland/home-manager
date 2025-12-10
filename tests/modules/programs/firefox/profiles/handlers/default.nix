modulePath:
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = getAttrFromPath modulePath config;
  firefoxMockOverlay = import ../../setup-firefox-mock-overlay.nix modulePath;
in
{
  imports = [ firefoxMockOverlay ];

  config = mkIf config.test.enableBig (
    setAttrByPath modulePath {
      enable = true;
      profiles.handlers = {
        id = 0;
        handlers = {
          mimeTypes = {
            "application/pdf" = {
              action = 2;
              ask = false;
              handlers = [
                {
                  name = "Hello App";
                  path = "${pkgs.hello}/bin/hello";
                }
              ];
              extensions = [ "pdf" ];
            };
            "text/html" = {
              action = 4;
              ask = true;
              extensions = [
                "html"
                "htm"
              ];
            };
          };
          schemes = {
            mailto = {
              action = 2;
              ask = false;
              handlers = [
                {
                  name = "Gmail";
                  uriTemplate = "https://mail.google.com/mail/?extsrc=mailto&url=%s";
                }
              ];
            };
            http = {
              action = 3;
              ask = true;
            };
          };
        };
      };
    }
    // {
      nmt.script = ''
        assertFileContent \
          home-files/${cfg.configPath}/handlers/handlers.json \
          ${./expected-handlers.json}
      '';
    }
  );
}
