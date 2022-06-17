{pkgs, ...}:
{
  boot.isContainer = true;

  services.openssh = {
    enable = true;
  };

  # PUBLICALLY KNOWN KEY, NEVER USE ON A MACHINE REACHABLE FROM THE NET
  environment.etc."ssh/ssh_host_ed25519_key"= {
    text = ''
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
      QyNTUxOQAAACB65IGHpPIP0Omsj5s+/sI5HmLA8UiOMBIhJ9uT+/IsngAAAJAl6naNJep2
      jQAAAAtzc2gtZWQyNTUxOQAAACB65IGHpPIP0Omsj5s+/sI5HmLA8UiOMBIhJ9uT+/Isng
      AAAEA57FKwRfEQyLSgywS3zbHU4mFJAbsbhetO7gxAs1kWMXrkgYek8g/Q6ayPmz7+wjke
      YsDxSI4wEiEn25P78iyeAAAACnJvb3RAbml4b3MBAgM=
      -----END OPENSSH PRIVATE KEY-----
    '';
    mode = "0600";
  };

  environment.etc."ssh/ssh_host_ed25519_key.pub" = {
    text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHrkgYek8g/Q6ayPmz7+wjkeYsDxSI4wEiEn25P78iye
    '';
    mode = "0644";
  };

  sops.defaultSopsFile = ./secrets/mosquitto.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.gnupg.sshKeyPaths = [];
  sops.secrets.br1passwd = {};
  sops.secrets.br2passwd = {};

  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
      }
    ];

    bridges.br1 = {
      addresses = [ { address = "127.0.0.2"; } ];
      topics = [ "# in" ];
      settings = {
        remote_password = "!!BR1_PASSWORD!!";
      };
    };

    bridges.br2 = {
      addresses = [ { address = "127.0.0.3"; } ];
      topics = [ "# in" ];
      settings = {
        remote_password = "!!BR2_PASSWORD!!";
      };
    };
  };

}
