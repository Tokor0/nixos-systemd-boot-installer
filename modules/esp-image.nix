{ ... }:

{
  flake.modules.nixos.esp-image = { config, lib, pkgs, ... }:

    let
      efiArch = pkgs.stdenv.hostPlatform.efiArch;

      systemdBootEfi =
        "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

      kernel =
        "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";

      initrd =
        "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";

      dtCfg = config.hardware.deviceTree;
      hasDTB = dtCfg.enable && dtCfg.name != null;
      dtbPath = lib.optionalString hasDTB "${dtCfg.package}/${dtCfg.name}";

      kernelParams = "init=${config.system.build.toplevel}/init "
        + lib.concatStringsSep " " config.boot.kernelParams;

      loaderConf = pkgs.writeText "loader.conf" (''
        timeout ${toString config.boot.loader.timeout}
        default nixos-installer.conf
      '' + lib.optionalString config.isoImage.forceTextMode ''
        console-mode 0
      '');

      defaultEntry = pkgs.writeText "nixos-installer.conf" (''
        title NixOS Installer
        sort-key nixos
        linux /kernel
        initrd /initrd
        options ${kernelParams}
      '' + lib.optionalString hasDTB ''
        devicetree /dtb
      '');

      espImage = pkgs.runCommand "esp-image.img"
        {
          nativeBuildInputs = with pkgs; [ mtools dosfstools libfaketime ];
          passthru = { inherit efiArch; };
        }
        ''
          kernelSize=$(stat -c %s ${kernel})
          initrdSize=$(stat -c %s ${initrd})
          bootloaderSize=$(stat -c %s ${systemdBootEfi})
          dtbSize=${if hasDTB then "$(stat -c %s ${dtbPath})" else "0"}

          # 2 MiB headroom for FAT metadata and config files
          totalSize=$(( kernelSize + initrdSize + bootloaderSize + dtbSize + 2 * 1024 * 1024 ))
          totalSizeMB=$(( (totalSize + 1048575) / 1048576 ))

          truncate -s "''${totalSizeMB}M" "$out"
          faketime "1970-01-01 00:00:00" mkfs.vfat -n ESP "$out"

          # Directory structure
          mmd -i "$out" ::EFI
          mmd -i "$out" ::EFI/BOOT
          mmd -i "$out" ::loader
          mmd -i "$out" ::loader/entries

          # systemd-boot binary
          mcopy -i "$out" ${systemdBootEfi} "::EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI"

          # Loader configuration
          mcopy -i "$out" ${loaderConf} ::loader/loader.conf
          mcopy -i "$out" ${defaultEntry} ::loader/entries/nixos-installer.conf

          # Kernel and initrd
          mcopy -i "$out" ${kernel} ::kernel
          mcopy -i "$out" ${initrd} ::initrd

          # Device tree
          ${lib.optionalString hasDTB ''mcopy -i "$out" ${dtbPath} ::dtb''}
        '';

    in
    {
      config.system.build = { inherit espImage; };
    };
}
