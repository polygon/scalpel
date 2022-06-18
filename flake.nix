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

    nixosModules.scalpel = import ./modules/scalpel;
    nixosModule = self.nixosModules.scalpel;
      
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
          ./example/scalpel.nix 
        ];
        specialArgs = { prev = base_sys; };
      };

      exampleContainerManual = base_sys.extendModules {
        modules = [ 
          ./example/scalpel-manual.nix 
        ];
        specialArgs = { prev = base_sys; inherit (self) mk_scalpel; };
      };
    };
  };
}
