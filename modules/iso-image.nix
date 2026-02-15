{ inputs, ... }:

{
  flake.modules.nixos.iso-image = { config, lib, pkgs, ... }:

    let
      cfg = config.isoImage;

      isoImage = pkgs.callPackage "${inputs.nixpkgs}/nixos/lib/make-iso9660-image.nix" {
        inherit (cfg) isoName volumeID compressImage squashfsCompression;

        syslinux = null;

        efiBootable = true;
        efiBootImage = "boot/efi.img";

        squashfsContents = [ config.system.build.toplevel ];

        contents = [
          {
            source = config.system.build.espImage;
            target = "/boot/efi.img";
          }
        ] ++ cfg.contents;
      };

    in
    {
      imports = [ inputs.self.modules.nixos.esp-image ];

      options.isoImage = {
        isoName = lib.mkOption {
          type = lib.types.str;
          default = "nixos.iso";
          description = "The file name of the generated ISO image.";
        };

        volumeID = lib.mkOption {
          type = lib.types.str;
          default = "NIXOS_ISO";
          description = "The volume ID of the ISO image, used as a label to find the disc.";
        };

        compressImage = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to compress the ISO image with zstd.";
        };

        squashfsCompression = lib.mkOption {
          type = lib.types.str;
          default = "xz -Xdict-size 100%";
          description = "Compression algorithm for the squashfs nix store.";
        };

        contents = lib.mkOption {
          default = [ ];
          description = "Additional files and directories to place on the ISO.";
          type = lib.types.listOf (lib.types.submodule {
            options = {
              source = lib.mkOption {
                type = lib.types.path;
                description = "The source file or directory.";
              };
              target = lib.mkOption {
                type = lib.types.str;
                description = "The target path on the ISO.";
              };
            };
          });
        };
      };

      config.system.build = { inherit isoImage; };
    };
}
