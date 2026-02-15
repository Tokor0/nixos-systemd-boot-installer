{ inputs, ... }:

{
  flake.nixosConfigurations.test-iso = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      inputs.self.modules.nixos.live
      {
        boot.kernelPackages = inputs.nixpkgs.legacyPackages.aarch64-linux.linuxPackages_latest;
        system.stateVersion = "25.05";
      }
    ];
  };
}
