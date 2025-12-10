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
    {
      home.enableNixpkgsReleaseCheck = false;
    }
    // setAttrByPath modulePath {
      enable = true;

      profiles.test = {
        id = 0;
        handlers = {
          mimeTypes = {
            "application/pdf" = {
              action = 2;
              handlers = [
                {
                  name = "Test";
                  path = "${pkgs.hello}/bin/hello";
                  uriTemplate = "https://example.com/?url=%s";
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
        "'application/pdf': handler can't have both 'path' and 'uriTemplate' set."
      ];
    }
  );
}
