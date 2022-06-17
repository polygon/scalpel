{lib, config, pkgs, prev, ...}:
let
  start = "${prev.config.systemd.services.mosquitto.serviceConfig.ExecStart}";
  mosquitto_cfgfile = builtins.head (builtins.match ".*[[:space:]]([^[:space:]]+)$" "${start}");
  decrypted_cfgfile = "/run/mosquitto.cfg";
  secret_file = config.sops.secrets.password.path;
  replacer = pkgs.writeShellScript ''mosquitto-replacer'' ''
    PASSWORD=$(cat ${secret_file})
    sed -e "s/!!PASSWORD!!/''${PASSWORD}/g" ${mosquitto_cfgfile} > ${decrypted_cfgfile}
    chown mosquitto:mosquitto ${decrypted_cfgfile}
  '';
in
{
  systemd.services.mosquitto.serviceConfig.ExecStartPre = [ "+${replacer}" ];
  systemd.services.mosquitto.serviceConfig.ExecStart = lib.mkForce (
    builtins.replaceStrings [ "${mosquitto_cfgfile}" ] [ "${decrypted_cfgfile}"] "${start}"
  );
}
