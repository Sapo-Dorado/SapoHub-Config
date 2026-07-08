# Fallback disk device, used until a real one exists for a given
# hostname. Bootstrapping a host writes hardware/<hostname>-disk-device.nix
# instead, which takes priority automatically.
{
  sapohubDiskDevice = "/dev/sda";
}
