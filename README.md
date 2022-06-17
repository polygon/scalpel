# Scalpel

Minimally invasive safe secret provisioning to Nix-generated service config files.

## The issue

NixOS has some fairly nice secrets provisioning with packages like [sops-nix](https://github.com/Mic92/sops-nix/) or [agenix](https://github.com/ryantm/agenix). 
Secrets are decrypted at activation time and will not end up in your store where they may be accessible to anyone.
