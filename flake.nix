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

      # Explicit, hand-written prefs — single source of truth, referenced
      # by both nixosConfigurations.<host> below and nixosModules.default.
      # Wins over anything synced into sapohub-prefs.nix from the Settings
      # UI (that file's values are wrapped in lib.mkDefault by
      # `sapohub-deploy --sync-prefs`).
      prefs = {
        # "preview" is My Plate's one non-default dashboard_buttons option
        # (MyPlateWeb.TaskPreview); leaving this unset falls back to the
        # module's built-in icon+title default tile.
        "dashboard_button.my_plate" = "preview";
        # Only show My Plate's "due today" count in the statusline —
        # drops the built-in core.scheduler/core.snapshot items. Unset
        # would fall back to showing every item (see
        # SapoCore.Statusline for the full fallback rule).
        "statusline_order" = "my_plate.due";
      };

      hosts = {
        test = { };
      };

      mkHost = hostname: _hostArgs: sapohub.lib.mkFreshMachine {
        inherit hostname sshKey system modules depsHash npmDepsHash;
        hardwareDir = ./hardware;
        extraNixosModules = [
          ./sapohub-prefs.nix
          { services.sapohub.prefs = prefs; }
        ];
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
            prefs = lib.mapAttrs (_: lib.mkDefault) prefs;
            # Off by default here (an existing machine keeps its own
            # networking) — opt in explicitly if wanted:
            #   tailscale.enable = lib.mkDefault true;
            #   tailscale.authKeyFile = lib.mkDefault "/etc/sapohub/tailscale-authkey";
          };
          nixpkgs.config.allowUnfree = lib.mkDefault true;
        };
    };
}
