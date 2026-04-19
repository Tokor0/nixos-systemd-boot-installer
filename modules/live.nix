{ inputs, ... }:

{
  flake.modules.nixos.live = { config, lib, pkgs, ... }:

    {
      imports = [ inputs.self.modules.nixos.iso-image ];

      config = {
        boot.loader.grub.enable = lib.mkImageMediaOverride false;

        boot.kernelParams = lib.optionals (!config.boot.initrd.systemd.enable) [
          "boot.shell_on_fail"
          "root=LABEL=${config.isoImage.volumeID}"
        ];

        boot.initrd.availableKernelModules = [
          "squashfs"
          "iso9660"
          "uas"
          "overlay"
        ];

        boot.initrd.kernelModules = [
          "loop"
          "overlay"
        ];

        boot.initrd.supportedFilesystems = [ "vfat" ];

        boot.loader.timeout = 10;

        lib.isoFileSystems = {
          "/" = lib.mkImageMediaOverride {
            fsType = "tmpfs";
            options = [ "mode=0755" ];
          };

          "/iso" = lib.mkImageMediaOverride {
            fsType = "iso9660";
            device =
              if config.boot.initrd.systemd.enable
              then "/dev/disk/by-label/${config.isoImage.volumeID}"
              else "/dev/root";
            neededForBoot = true;
            noCheck = true;
          };

          "/nix/.ro-store" = lib.mkImageMediaOverride {
            fsType = "squashfs";
            device = "${lib.optionalString config.boot.initrd.systemd.enable "/sysroot"}/iso/nix-store.squashfs";
            options = [
              "loop"
            ] ++ lib.optional (config.boot.kernelPackages.kernel.kernelAtLeast "6.2") "threads=multi";
            neededForBoot = true;
          };

          "/nix/.rw-store" = lib.mkImageMediaOverride {
            fsType = "tmpfs";
            options = [ "mode=0755" ];
            neededForBoot = true;
          };

          "/nix/store" = lib.mkImageMediaOverride {
            overlay = {
              lowerdir = [ "/nix/.ro-store" ];
              upperdir = "/nix/.rw-store/store";
              workdir = "/nix/.rw-store/work";
            };
          };
        };

        fileSystems = lib.mkImageMediaOverride config.lib.isoFileSystems;
        swapDevices = lib.mkImageMediaOverride [ ];
        boot.initrd.luks.devices = lib.mkImageMediaOverride { };

        boot.postBootCommands = ''
          ${config.nix.package.out}/bin/nix-store --load-db < /nix/store/nix-path-registration
          touch /etc/NIXOS
          ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
        '';
      };
    };
}
