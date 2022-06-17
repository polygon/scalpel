{
  inputs.nixpkgs.url = github:NixOS/nixpkgs;
  inputs.sops-nix.url = github:Mic92/sops-nix;
  outputs = { self, nixpkgs, sops-nix }: 
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {

    mk_scalpel = {matchers, source, destination, user ? null, group ? null, mode ? null}:
      pkgs.callPackage ./packages/scalpel.nix {
        inherit matchers source destination user group mode;
      };
      
    nixosConfigurations.example_container = let
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
      specialArgs = { prev = sys; inherit (self) mk_scalpel; };
    };
  };
}
