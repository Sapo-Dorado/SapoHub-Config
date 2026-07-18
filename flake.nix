# Personal SapoHub config — my_plate, storage, projects, reminders,
# recipes, and the personal-modules repo's magic_proxies +
# youtube_download, everything else default.
#
# Bootstrap a machine with:
#   <path-to-SapoHub-2.0>/scripts/bootstrap.sh <ip> --hostname <name> --flake-path .
#
# --hostname must match a key in `hosts` below (or add one). Each host
# gets its own hardware/<hostname>-{hardware-configuration,disk-device}.nix,
# generated on first bootstrap.
{
  description = "My SapoHub config — my_plate, storage, projects, reminders, recipes, magic_proxies, youtube_download";

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
      lib = nixpkgs.lib;
      claude-code-nix = sapohub.inputs.claude-code-nix;

      # Machine-owned, written by `sapohub-deploy --sync-prefs` into
      # .sapohub/sapohub-prefs.nix at this repo's own root (see
      # nix/deploy-script.nix in SapoHub-2.0). No stub needs to exist up
      # front — pathExists just skips it until the first sync has run.
      prefsImport = lib.optional (builtins.pathExists ./.sapohub/sapohub-prefs.nix) ./.sapohub/sapohub-prefs.nix;

      modules = [
        sapohub.sapohubModules.my_plate
        sapohub.sapohubModules.storage
        sapohub.sapohubModules.projects
        sapohub.sapohubModules.reminders
        sapohub.sapohubModules.recipes
        personal-modules.sapohubModules.magic_proxies
        personal-modules.sapohubModules.youtube_download
      ];
      depsHash = "sha256-xNO7J5/zhUsQF2Wu1uhuemj0GnjXc77fG4i4pADTx9w=";
      npmDepsHash = "sha256-iHOJ/cXZOsPeEnKaDBYbEj7ClLpJ5hbmrZwnLmTvrdU=";

      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDOm17LfZVvLbzE+buuBRtK3FVQsBul2R4C+zLE+HSK sapo-hub";

      hosts = {
        test = { };
      };

      mkHost = hostname: _hostArgs: sapohub.lib.mkFreshMachine {
        inherit hostname sshKey system modules depsHash npmDepsHash;
        hardwareDir = ./hardware;
        extraNixosModules = [
          # DB always stores/queries UTC — this only affects how times
          # render in the UI (statusline clock, deploy timestamps, etc).
          { services.sapohub.timezone = "America/Los_Angeles"; }
          {
            services.sapohub.gitIdentity = {
              name = "Nicholas Brown";
              email = "sapodorado@proton.me";
            };
          }
          {
            services.sapohub = {
              deploy.repoUrl = "https://github.com/Sapo-Dorado/SapoHub-Config";
              deploy.updateInputNames = [ "sapohub" "personal-modules" ];
              assistant.browser.enable = true;
            };
          }
        ] ++ prefsImport;
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
      #
      # Deliberately does NOT set deploy.repoUrl or
      # assistant.browser.enable, even as mkDefault — those describe how
      # to deploy/run THIS repo itself (used by its own `hosts.test`
      # below), not something a config importing this module as a
      # dependency should silently inherit. A previous version set both
      # here, and a real consumer (a separate personal nixos flake that
      # imports this module for its own nixosConfigurations.nixos) picked
      # up deploy.repoUrl pointing at THIS repo instead of its own —
      # sapohub-deploy then cloned/rebuilt the wrong flake entirely,
      # since this repo doesn't define nixosConfigurations.nixos. Every
      # consumer must set deploy.repoUrl (and assistant.browser.enable,
      # if wanted) explicitly, exactly like deploy.flakeAttr already
      # forces them to.
      nixosModules.default = { pkgs, lib, ... }:
        let
          flakePkgs = import nixpkgs {
            inherit (pkgs) system;
            config.allowUnfree = true;
            overlays = [ claude-code-nix.overlays.default ];
          };
        in
        {
          # No .sapohub/sapohub-prefs.nix import here — that file (and its
          # `sapohub-deploy --sync-prefs` sync) belongs to whichever repo is
          # actually deploy.flakePath for a given deployment. For anyone
          # importing this bundle, that's THEIR own outer flake checkout,
          # not this one — see `prefsImport` above for how this repo's own
          # `hosts.test` wires up its own copy.
          imports = [ sapohub.nixosModules.default ];
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
