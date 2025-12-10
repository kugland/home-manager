modulePath:
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  firefoxMockOverlay = import ../../setup-firefox-mock-overlay.nix modulePath;
in
{
  imports = [ firefoxMockOverlay ];

  config = mkIf config.test.enableBig (
    setAttrByPath modulePath {
      enable = true;
      profiles.handlers-without-action = {
        id = 0;
        handlers = {
          mimeTypes = {
            "application/pdf" = {
              action = 1;
              handlers = [
                {
                  name = "Test";
                  path = "${pkgs.hello}/bin/hello";
                }
              ];
              extensions = [ "pdf" ];
            };
          };
        };
      };
    }
    // {
      test.asserts.assertions.expected = [
        "'application/pdf': handlers can only be set when 'action' is set to 2 (Use helper app)."
      ];
    }
  );
}
