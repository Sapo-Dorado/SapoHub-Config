# Personal SapoHub config — my_plate (todo) only, everything else default.
#
# Each machine you deploy gets its own nixosConfigurations.<hostname>,
# built via sapohub.lib.mkFreshMachine — see that function in
# SapoHub-2.0's flake.nix for what it wires up (disko + a per-hostname
# generated hardware config + Tailscale-only networking +
# services.sapohub). Bootstrap a machine with:
#
#   <path-to-SapoHub-2.0>/scripts/bootstrap.sh <ip> \
#     --hostname <name> --flake-path .
#
# --hostname must match a key in `hosts` below (or you add one). It's
# also the prefix bootstrap.sh uses for this machine's generated
# hardware/<hostname>-{hardware-configuration,disk-device}.nix — that's
# what lets this one repo manage multiple distinct machines over time
# without their hardware configs clobbering each other.
#
# CHANGE ME before deploying: sshKey below, and depsHash/npmDepsHash if
# you add or remove modules (nix prints the expected hash on a
# mismatch — paste it in).
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
      # Placeholder — replace with the hash `nix build` reports on first
      # run (deps differ from SapoHub-2.0's own default hello + my_plate
      # combo, since hello is dropped here).
      depsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      sshKey = "ssh-ed25519 AAAA..."; # CHANGE ME — your SSH public key

      # One entry per machine. Add more as you bring more hosts online —
      # each needs a unique hostname (also used to bootstrap it: see the
      # header comment).
      hosts = {
        test = { };
        # office-desktop = { };
      };

      mkHost = hostname: _hostArgs: sapohub.lib.mkFreshMachine {
        inherit hostname sshKey system modules depsHash npmDepsHash;
        hardwareDir = ./hardware;
        # Machine-owned, kept in sync by deploys — see sapohub-prefs.nix.
        # Shared across all hosts in this repo (dashboard/UI preferences
        # are "how I like SapoHub to look", not really per-machine).
        extraNixosModules = [ ./sapohub-prefs.nix ];
      };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost hosts;
    };
}
