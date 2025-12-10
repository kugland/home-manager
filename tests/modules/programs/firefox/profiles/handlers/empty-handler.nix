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
      profiles.empty-handler = {
        id = 0;
        handlers = {
          mimeTypes = {
            "application/pdf" = {
              action = 2;
              ask = false;
              handlers = [
                {
                  # Empty handler object - no default
                }
              ];
              extensions = [ "pdf" ];
            };
          };
        };
      };
    }
    // {
      nmt.script = ''
        assertFileContent \
          home-files/${cfg.configPath}/empty-handler/handlers.json \
          ${./expected-empty-handler.json}
      '';
    }
  );
}
