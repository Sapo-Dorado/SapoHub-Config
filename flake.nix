# Personal SapoHub config — my_plate, storage, projects, reminders, and
# the personal-modules repo's magic_proxies + youtube_download,
# everything else default.
#
# Bootstrap a machine with:
#   <path-to-SapoHub-2.0>/scripts/bootstrap.sh <ip> --hostname <name> --flake-path .
#
# --hostname must match a key in `hosts` below (or add one). Each host
# gets its own hardware/<hostname>-{hardware-configuration,disk-device}.nix,
# generated on first bootstrap.
{
  description = "My SapoHub config — my_plate, storage, projects, reminders, magic_proxies, youtube_download";

  inputs = {
    sapohub.url = "github:Sapo-Dorado/SapoHub-2.0";
    # PersonalModules is a private repo — the github: fetcher needs an
    # authenticated API call. sapohub-deploy forwards GITHUB_TOKEN (from
    # the target machine's root-only secrets file) into Nix's
    # access-tokens config before running nixos-rebuild switch, so this
    # is authenticated on the real deploy host the same way it would be
    # anywhere else a GITHUB_TOKEN is configured for nix.
    personal-modules.url = "github:Sapo-Dorado/PersonalModules";
  };

  outputs = { self, sapohub, personal-modules, ... }:
    let
      system = "x86_64-linux";
      nixpkgs = sapohub.inputs.nixpkgs;
      claude-code-nix = sapohub.inputs.claude-code-nix;

      modules = [
        sapohub.sapohubModules.my_plate
        sapohub.sapohubModules.storage
        sapohub.sapohubModules.projects
        sapohub.sapohubModules.reminders
        personal-modules.sapohubModules.magic_proxies
        personal-modules.sapohubModules.youtube_download
      ];
      depsHash = "sha256-xNO7J5/zhUsQF2Wu1uhuemj0GnjXc77fG4i4pADTx9w=";
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
          # DB always stores/queries UTC — this only affects how times
          # render in the UI (statusline clock, deploy timestamps, etc).
          { services.sapohub.timezone = "America/Los_Angeles"; }
          {
            services.sapohub.gitIdentity = {
              name = "Nicholas Brown";
              email = "sapodorado@proton.me";
            };
          }
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

            timezone = lib.mkDefault "America/Los_Angeles";
            gitIdentity = {
              name = lib.mkDefault "Nicholas Brown";
              email = lib.mkDefault "sapodorado@proton.me";
            };
            # Off by default here (an existing machine keeps its own
            # networking) — opt in explicitly if wanted:
            #   tailscale.enable = lib.mkDefault true;
            #   tailscale.authKeyFile = lib.mkDefault "/etc/sapohub/tailscale-authkey";
          };
          nixpkgs.config.allowUnfree = lib.mkDefault true;
        };
    };
}
