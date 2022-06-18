{self, config, pkgs, lib, ...}:

with lib;

let
  cfg = config.scalpel;

  trafos = builtins.map (trafo:
      let
        matchers = builtins.listToAttrs (builtins.map (matcher:
          { name = "${matcher.pattern}"; value = "${matcher.secret}"; }
        ) (builtins.attrValues trafo.matchers));
      in
      self.mk_scalpel {
        inherit matchers;
        inherit (trafo) source destination mode group;
        user = trafo.owner;
      }) (builtins.attrValues cfg.trafos);

  trafos_call = builtins.concatStringsSep "\n" (
    builtins.map (trafo: "${trafo}") trafos
  );

  matcherType = types.submodule({config, ...}:{
    options = {
      pattern = mkOption {
        type = types.str;
        default = config._module.args.name;
        description = ''
          Pattern to search for (!!PATTERN!!)
        '';
      };
      secret = mkOption {
        type = types.str;
        description = ''
          Path to secret
        '';
      };
    };
  });
  trafoType = types.submodule({config, ...}:{
    options = {
      name = mkOption {
        type = types.str;
        default = config._module.args.name;
        description = ''
          Name of the trafo
        '';
      };
      source = mkOption {
        type = types.str;
        description = ''
          Source file path
        '';
      };
      destination = mkOption {
        type = types.str;
        default = "${cfg.secretsDir}/${config.name}";
        description = ''
          Destination file path (overriding this may persist your secrets)
        '';
      };
      mode = mkOption {
        type = types.str;
        default = "0400";
        description = ''
          Destination file mode
        '';
      };
      owner = mkOption {
        type = types.str;
        default = "0";
        description = ''
          Destination file owner
        '';
      };
      group = mkOption {
        type = types.str;
        default = config.users.users.${config.owner}.group or "0";
        description = ''
          Destination file owner
        '';
      };
      matchers = mkOption {
        type = types.attrsOf matcherType;
        default = { };
        description = ''
          Matcher definitions
        '';
      };
    };
  });
in
{
  options.scalpel = {
    secretsDir = mkOption {
      type = types.path;
      default = "/run/scalpel";
      description = ''
        Folder where secrets are stored
      '';
    };
    trafos = mkOption {
      type = types.attrsOf trafoType;
      default = { };
      description = ''
        File transformator definitions
      '';
    };
  };

  config = mkIf (cfg.trafos != { }) {
    system.activationScripts.scalpelCreateStore = {
      text = ''
        echo "[scalpel] Ensuring existance of ${cfg.secretsDir}"
        mkdir -p ${cfg.secretsDir}
        grep -q "${cfg.secretsDir} ramfs" /proc/mounts || mount -t ramfs none "${cfg.secretsDir}" -o nodev,nosuid,mode=0751

        echo "[scalpel] Clearing old secrets from ${cfg.secretsDir}"
        rm -rf ${cfg.secretsDir}/{*,.*}
      '';
      deps = [ "specialfs" ];
    };

    system.activationScripts.scalpel = {
      text = trafos_call;
      deps = [
        "users"
        "groups"
        "specialfs"
        "scalpelCreateStore"  
      ] ++ optional (builtins.hasAttr "setupSecrets" config.system.activationScripts) "setupSecrets"
        ++ optional (builtins.hasAttr "agenix" config.system.activationScripts) "agenix";
    };
  };
}