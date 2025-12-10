{
  config,
  lib,
  pkgs,
  appName,
  package,
  modulePath,
  profilePath,
}:
with lib;
let
  jsonFormat = pkgs.formats.json { };

  # Process a handler entry, validating path vs uriTemplate
  processHandler =
    mimeTypeOrScheme: handler:
    let
      hasPath = handler.path or null != null;
      hasUriTemplate = handler.uriTemplate or null != null;
      hasName = handler.name or null != null;
    in
    {
      assertion = !(hasPath && hasUriTemplate);
      message = "'${mimeTypeOrScheme}': handler can't have both 'path' and 'uriTemplate' set.";
      result =
        (optionalAttrs hasName { inherit (handler) name; })
        // (optionalAttrs hasPath { inherit (handler) path; })
        // (optionalAttrs hasUriTemplate { inherit (handler) uriTemplate; });
    };

  # Process all handlers for a mime type or scheme
  processHandlers =
    name: value:
    let
      hasHandlers = value.handlers != [ ];
      processedHandlers = map (processHandler name) value.handlers;
      handlerAssertions = map (h: { inherit (h) assertion message; }) processedHandlers;
      handlerResults = map (h: h.result) processedHandlers;
    in
    {
      assertions = handlerAssertions ++ [
        {
          assertion = !hasHandlers || value.action == 2;
          message = "'${name}': handlers can only be set when 'action' is set to 2 (Use helper app).";
        }
      ];
      result = {
        inherit (value) action ask;
      }
      // optionalAttrs hasHandlers { handlers = handlerResults; };
    };

  # Process mime types, including extensions field
  processMimeType =
    name: value:
    let
      processed = processHandlers name value;
    in
    {
      inherit (processed) assertions;
      result = processed.result // {
        inherit (value) extensions;
      };
    };

  # Process all mime types
  processedMimeTypes = mapAttrs processMimeType (config.mimeTypes or { });
  mimeTypeAssertions = flatten (mapAttrsToList (_: v: v.assertions) processedMimeTypes);
  mimeTypeResults = mapAttrs (_: v: v.result) processedMimeTypes;

  # Process all schemes
  processedSchemes = mapAttrs processHandlers (config.schemes or { });
  schemeAssertions = flatten (mapAttrsToList (_: v: v.assertions) processedSchemes);
  schemeResults = mapAttrs (_: v: v.result) processedSchemes;

  # Combine all assertions
  allAssertions = mimeTypeAssertions ++ schemeAssertions;

  # Build the final handlers.json structure
  settings = {
    defaultHandlersVersion = { };
    isDownloadsImprovementsAlreadyMigrated = false;
    mimeTypes = mimeTypeResults;
    schemes = schemeResults;
  };

  # Common options shared between mimeTypes and schemes
  commonHandlerOptions = {
    action = mkOption {
      type = types.enum [
        0
        1
        2
        3
        4
      ];
      default = 1;
      description = ''
        The action to take for this MIME type / URL scheme. Possible values:
        - 0: Save file
        - 1: Always ask
        - 2: Use helper app
        - 3: Open in ${appName}
        - 4: Use system default
      '';
    };

    ask = mkOption {
      type = types.bool;
      default = true;
      description = ''
        If true, the user is asked what they want to do with the file.
        If false, the action is taken without user intervention.
      '';
    };

    handlers = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                The display name of the handler.
              '';
            };

            path = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                The native path to the executable to be used.
                Choose between path or uriTemplate.
              '';
            };

            uriTemplate = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                A URL to a web based application handler.
                The URL must be https and contain a %s to be used for substitution.
                Choose between path or uriTemplate.
              '';
            };
          };
        }
      );
      default = [ ];
      description = ''
        An array of handlers with the first one being the default.
        If you don't want to have a default handler, use an empty object for the first handler.
        Only valid when action is set to 2 (Use helper app).
      '';
    };
  };
in
{
  imports = [ (pkgs.path + "/nixos/modules/misc/meta.nix") ];

  meta.maintainers = with maintainers; [ kugland ];

  options = {
    enable = mkOption {
      type = types.bool;
      default = config.schemes != { } || config.mimeTypes != { };
      internal = true;
    };

    force = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to force replace the existing handlers configuration.
      '';
    };

    mimeTypes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = commonHandlerOptions // {
            extensions = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [
                "jpg"
                "jpeg"
              ];
              description = ''
                List of file extensions associated with this MIME type.
              '';
            };
          };
        }
      );
      default = { };
      example = literalExpression ''
        {
          "application/pdf" = {
            action = 2;
            ask = false;
            handlers = [
              {
                name = "Okular";
                path = "''${pkgs.okular}/bin/okular";
              }
            ];
            extensions = [ "pdf" ];
          };
        }
      '';
      description = ''
        Attribute set mapping MIME types to their handler configurations.
      '';
    };

    schemes = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = commonHandlerOptions;
        }
      );
      default = { };
      example = literalExpression ''
        {
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
        }
      '';
      description = ''
        Attribute set mapping URL schemes to their handler configurations.
      '';
    };

    assertions = mkOption {
      type = types.listOf types.unspecified;
      default = allAssertions;
      internal = true;
      readOnly = true;
      description = ''
        Validation assertions for handler configuration.
      '';
    };

    settings = mkOption {
      type = jsonFormat.type;
      default = settings;
      internal = true;
      readOnly = true;
      description = ''
        Resulting handlers.json settings.
      '';
    };
  };
}
