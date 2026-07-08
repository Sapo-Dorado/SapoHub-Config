# sapohub-config

My personal SapoHub deployment config. Modules enabled: `my_plate`
(todo) only — everything else is [SapoHub-2.0](https://github.com/Sapo-Dorado/SapoHub-2.0)'s
defaults.

## Before deploying

1. Set `sshKey` in `flake.nix` to your own SSH public key.
2. Resolve the placeholder `depsHash`/`npmDepsHash` in `flake.nix` — run
   a build, nix will report the correct hash on a mismatch:
   ```sh
   nix build .#nixosConfigurations.hub.config.system.build.toplevel
   ```
   Paste the reported hash in, repeat for the second one if it also
   mismatches.
3. Prepare a `SECRET_KEY_BASE` (or let the bootstrap process generate
   one for you — see below) for `/etc/sapohub/secrets.env` on the
   target.

## Deploying

This flake is self-contained and deployable the same way SapoHub-2.0's
own `nixosConfigurations.fresh-machine` example is: disko disk layout +
a hardware config generated per-machine (not hand-written) + Tailscale
(no public exposure) + `services.sapohub`.

Point a nixos-anywhere run at this repo's `#hub` attribute — see
[SapoHub-2.0/scripts/bootstrap.sh](https://github.com/Sapo-Dorado/SapoHub-2.0/blob/main/scripts/bootstrap.sh)
for the exact invocation shape (`--generate-hardware-config` for
hardware-agnostic bootstrap, `--extra-files` for seeding secrets/a
Tailscale auth key before first boot). That script currently targets
SapoHub-2.0's own bundled example flake rather than an arbitrary config
repo like this one — either adapt a local copy of it to point here, or
run the underlying `nix run github:nix-community/nixos-anywhere -- ...`
command directly against this repo's flake with the same flags.

## Updating

Once deployed, `/etc/sapohub-config` on the target is a checkout of this
repo (`services.sapohub.deploy.flakePath`). SSH in and run
`sapohub-deploy`, or use the Settings page's Deploy button (which also
syncs UI preferences from Settings back into `sapohub-prefs.nix` here).
