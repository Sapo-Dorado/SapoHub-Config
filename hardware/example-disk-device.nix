# Fallback disk device — see SapoHub-2.0's own
# hardware/example-disk-device.nix for the full explanation. A real
# bootstrap run writes hardware/generated-disk-device.nix instead, which
# flake.nix prefers automatically if present.
{
  sapohubDiskDevice = "/dev/sda";
}
