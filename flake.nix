{
  inputs.nixpkgs.url = github:NixOS/nixpkgs;
  inputs.sops-nix.url = github:Mic92/sops-nix;
  outputs = { self, nixpkgs, sops-nix }: 
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
    nixosConfigurations.testex = let
      sys = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          sops-nix.nixosModules.sops
          ./example/system.nix
        ];
      };
    in
    sys.extendModules {
      modules = [ ./example/secrets.nix ];
      specialArgs = { prev = sys; };
    };
  };
}
