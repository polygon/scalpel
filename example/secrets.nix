{lib, config, pkgs, prev, mk_scalpel, ...}:
let
  start = "${prev.config.systemd.services.mosquitto.serviceConfig.ExecStart}";
  mosquitto_cfgfile = builtins.head (builtins.match ".*-c ([^[:space:]]+)" "${start}");
  decrypted_cfgfile = "/run/mosquitto.cfg";
  secret_file = config.sops.secrets.password.path;
  scalpel = mk_scalpel {
    matchers = { 
      "BR1_PASSWORD" = config.sops.secrets.br1passwd.path; 
      "BR2_PASSWORD" = config.sops.secrets.br2passwd.path;
    };
    source = mosquitto_cfgfile;
    destination = decrypted_cfgfile;
    user = "mosquitto";
    group = "mosquitto";
    mode = "0440";
  };
in
{
  systemd.services.mosquitto.serviceConfig.ExecStartPre = [ "+${scalpel}" ];
  systemd.services.mosquitto.serviceConfig.ExecStart = lib.mkForce (
    builtins.replaceStrings [ "${mosquitto_cfgfile}" ] [ "${decrypted_cfgfile}"] "${start}"
  );
}
