# Scalpel

Minimally invasive safe secret provisioning to Nix-generated service config files.

## The issue

NixOS has some fairly nice secrets provisioning with packages like [sops-nix](https://github.com/Mic92/sops-nix/) or [agenix](https://github.com/ryantm/agenix). Secrets are decrypted at activation time and will not end up in your store where they may be accessible to anyone.

Unfortunately, some services require secrets in their config files and don't support receiving secrets by other means, e.g., password files or environment variables. This could be solved by forking the module for the service and making it compatible, but that may require continuous effort to keep up with upstream changes. Submitting changes upstream to enhance the configuration possibilities is always a good idea but may not be viable for various reasons.

Scalpel provides tooling and a workflow based on `extendModules` to safely provision secrets to config files and then inject them into existing modules without having to fork them altogether.

## Prerequisites

You should already have secrets provisioning set up using, e.g., [sops-nix](https://github.com/Mic92/sops-nix/) or [agenix](https://github.com/ryantm/agenix). Please refer to these projects to get going.

## Interlude - `extendModules`

`extendModules` is a fairly recent feature of NixOS. I'll leave the exact explanation to someone more knowledgeable in the guts of the Nix module system, but the way we are using it here is:

Given a NixOS system configuration `sys = nixpkgs.lib.nixosSystem { ... }` we can derive a new configuration from it by calling `extendModules`. The interesting part is that we can now use `sys` and all the values inside of it in the new modules, e.g.:

```
    newsys = sys.extendModules {
        modules = [ ... ];
        specialArgs = { prev = sys; };
    };
```

What makes this so interesting is that you can replace a value in a module while taking reference to its previous value. Something that would previously end you up in an infinite recursion:

```
    environment.etc."test.cfg".text = ''${prev.config.environment.etc."test.cfg".text} more text here afterwards'';
```

This can be used to extract the names of configuration files from systemd service configurations and later inject different names back into them.

## Usage example

In the example, we will securely provision bridge-passwords for Mosquitto.

<details>
<summary><b>1. Create config with placeholder secrets</b></summary>

Create your Mosquitto config as usual. But use placeholders sandwiched between `!!` to name your secrets.

```
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
```

Also, you will configure your favorite secrets provisioning tool here to ensure that the secrets are later available at runtime:

```
  sops.secrets.br1passwd = {};
  sops.secrets.br2passwd = {};
```
</details>

<details>
<summary><b>2. Create a derived system to add secret-provisioning module</b></summary>

```
  nixosConfigurations = let
    base_sys = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sops-nix.nixosModules.sops
        ./example/system.nix
      ];
    };
  in {
    exampleContainer = base_sys.extendModules {
      modules = [ 
        self.nixosModules.scalpel
        ./example/secrets.nix 
      ];
      specialArgs = { prev = base_sys; };
    };
```

</details>

<details>
<summary><b>3. Write transformation rules for config file, replace service config</b></summary>

This is the part that is specific to each service. You will need to do some investigation to figure out how the configuration is passed to the service. Firstly, extract the path of the generated config file:

```
let
  start = "${prev.config.systemd.services.mosquitto.serviceConfig.ExecStart}";
  mosquitto_cfgfile = builtins.head (builtins.match ".*-c ([^[:space:]]+)" "${start}");
in
  (...)
```

Now, create a transformator to replace the secret placeholders in this file:

```
  scalpel.trafos."mosquitto.conf" = {
    source = mosquitto_cfgfile;
    matchers."BR1_PASSWORD".secret = config.sops.secrets.br1passwd.path;
    matchers."BR2_PASSWORD".secret = config.sops.secrets.br2passwd.path;
    owner = "mosquitto";
    group = "mosquitto";
    mode = "0440";
  };
```

Finally, replace the configuraton file with the newly created one:

```
  systemd.services.mosquitto.serviceConfig.ExecStart = lib.mkForce (
    builtins.replaceStrings [ "${mosquitto_cfgfile}" ] [ "${config.scalpel.trafos."mosquitto.conf".destination} "] "${start}"
  );
```
</details>

In this example, we only modified `systemd.services.mosquitto.serviceConfig.ExecStart` without forking the original service at all. This makes the change very minimally invasive and this config should remain compatible to most changes in the module of the service. The full example is provided in this flake as well.

## Run the example as a NixOS container

WARNING: THIS CONTAINER USES PUBLICALLY KNOWN PRIVATE KEYS. DO NOT USE THEM IN YOUR DEPLOYMENTS. EVER.

To quickly test the example, you can run it as a NixOS container:

```
sudo nixos-container create em --flake github:polygon/scalpel#exampleContainer
sudo nixos-container start em
sudo machinectl shell em
```

Inside the container, we can see the changes in action:

```
$ systemctl cat mosquitto | grep ExecStart
ExecStart=/nix/store/jd00fshpzdc8mm1gqf2x8s7pkb8yb8nj-mosquitto-2.0.14/bin/mosquitto -c /run/scalpel/mosquitto.conf

$ ls -la /run/scalpel/
-r--r-----  1 mosquitto mosquitto 373 Jun 18 17:10 mosquitto.conf

$ cat /run/scalpel/mosquitto.conf
[...]
connection br1
addresses 127.0.0.2:1883
topic # in
remote_password secretbridge1password
connection br2
addresses 127.0.0.3:1883
topic # in
remote_password moresecretbridge2
```

## Beta Warning

This module should be considered a Proof of Concept. It works, but I am sure that there are possible improvements security wise. Use it at your own risk. On another note, I am very happy to receive comments and pull requests for improvements.

## Acknowledgements

Thanks to the creators of [sops-nix](https://github.com/Mic92/sops-nix/) and [agenix](https://github.com/ryantm/agenix) for their fantastic work and sending me down this rabbit hole. A lot of the Scalpel module system was ~~blatantly ripped off~~ inspired by the modules provided from these projects.
