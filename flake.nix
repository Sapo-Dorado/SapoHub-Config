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
      nixpkgs = sapohub.inputs.nixpkgs;
      claude-code-nix = sapohub.inputs.claude-code-nix;

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

      built = sapohub.lib.mkSapoHub { inherit system modules depsHash npmDepsHash; };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost hosts;

      # Import into an EXISTING NixOS config — needs nothing beyond
      # `imports = [ sapohub-config.nixosModules.default ];`. This only sets
      # what's actually specific to this repo (module selection, the
      # unfree claude-code overlay wiring); secretsFile and
      # deploy.flakePath already have sensible defaults in SapoHub-2.0's
      # own module. `deploy.flakeAttr` has no universal default (it's
      # whatever the importing config calls its own host), so the
      # importing config still needs to set that one directly.
      nixosModules.default = { pkgs, lib, ... }:
        let
          flakePkgs = import nixpkgs {
            inherit (pkgs) system;
            config.allowUnfree = true;
            overlays = [ claude-code-nix.overlays.default ];
          };
        in
        {
          imports = [ sapohub.nixosModules.default ./sapohub-prefs.nix ];
          services.sapohub = {
            enable = lib.mkDefault true;
            package = lib.mkDefault built.package;
            cliPackage = lib.mkDefault built.cli;
            assistant.claudePackage = lib.mkDefault flakePkgs.claude-code;
          };
          nixpkgs.config.allowUnfree = lib.mkDefault true;
        };
    };
}
