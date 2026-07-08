# Personal SapoHub config — my_plate (todo) only, everything else default.
#
# Bootstrap a machine with:
#   <path-to-SapoHub-2.0>/scripts/bootstrap.sh <ip> --hostname <name> --flake-path .
#
# --hostname must match a key in `hosts` below (or add one). Each host
# gets its own hardware/<hostname>-{hardware-configuration,disk-device}.nix,
# generated on first bootstrap.
{
  description = "My SapoHub config — my_plate only";

  inputs = {
    sapohub.url = "github:Sapo-Dorado/SapoHub-2.0";
  };

  outputs = { self, sapohub, ... }:
    let
      system = "x86_64-linux";

      modules = [
        sapohub.sapohubModules.my_plate
      ];
      depsHash = "sha256-2gMs2ZCx1FHah25Zm/vYlSt5TQEZyZ92jHd3u1o6iW4=";
      npmDepsHash = "sha256-iHOJ/cXZOsPeEnKaDBYbEj7ClLpJ5hbmrZwnLmTvrdU=";

      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDOm17LfZVvLbzE+buuBRtK3FVQsBul2R4C+zLE+HSK sapo-hub";

      hosts = {
        test = { };
      };

      mkHost = hostname: _hostArgs: sapohub.lib.mkFreshMachine {
        inherit hostname sshKey system modules depsHash npmDepsHash;
        hardwareDir = ./hardware;
        extraNixosModules = [ ./sapohub-prefs.nix ];
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost hosts;
    };
}
