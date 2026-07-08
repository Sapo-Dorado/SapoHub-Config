# Fallback hardware configuration — see SapoHub-2.0's own
# hardware/example-hardware-configuration.nix for the full explanation.
# In short: DO NOT deploy with this file directly. A real bootstrap run
# (nixos-anywhere --generate-hardware-config) generates
# hardware/generated-hardware-configuration.nix instead, which flake.nix
# prefers automatically if present. This file only exists so the flake
# evaluates cleanly before that's ever been run.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
