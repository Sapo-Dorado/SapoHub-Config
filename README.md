# sapohub-config

My personal SapoHub deployment config. Modules enabled: `my_plate`
(todo), `storage`, and `magic_proxies` + `youtube_download` from the
private [PersonalModules](https://github.com/Sapo-Dorado/PersonalModules)
repo — everything else is [SapoHub-2.0](https://github.com/Sapo-Dorado/SapoHub-2.0)'s
defaults.

There are two ways to deploy this: bootstrap a fresh machine from
scratch (script-driven, wipes the target disk), or import this repo's
`nixosModules.default` into a NixOS config you already maintain. Both
end up running the same `services.sapohub` module; they just differ in
who owns the disk/filesystem/bootloader config.

## Before deploying (either path)

1. Set `sshKey` in `flake.nix` to your own SSH public key (used for root
   SSH access on any fresh-machine host — not needed for the
   existing-config path, since you already have access to that machine).
2. Resolve the placeholder `depsHash`/`npmDepsHash` in `flake.nix` if you
   change the `modules` list — run a build, nix reports the correct hash
   on a mismatch:
   ```sh
   nix build .#nixosConfigurations.test.config.system.build.toplevel
   ```
   Paste the reported hash in, repeat for the second one if it also
   mismatches.
3. Prepare a `SECRET_KEY_BASE` for `/etc/sapohub/secrets.env` on the
   target. The bootstrap script generates and seeds this automatically
   for fresh machines (Path 1). For an existing NixOS box (Path 2) you
   do it once by hand — see below.

## Path 1: fresh machine (nixos-anywhere)

Each host gets its own entry in the `hosts` attrset in `flake.nix` (the
attribute name is also the `nixosConfigurations` name and the prefix for
that host's generated hardware files). There's one host, `test`, to
start with — add more by adding entries to `hosts` and re-running the
bootstrap for each.

From a checkout of [SapoHub-2.0](https://github.com/Sapo-Dorado/SapoHub-2.0):

```sh
./scripts/bootstrap.sh <ip> --hostname test --flake-path /path/to/this/repo
```

This SSHes into the target (must be booted into a NixOS installer ISO),
generates `hardware/test-hardware-configuration.nix` and
`hardware/test-disk-device.nix` here, partitions the disk via disko,
seeds secrets and (optionally) a Tailscale auth key, installs, commits
and pushes the generated hardware files back into this repo, and clones
this repo onto the target at `/etc/sapohub-config` so future redeploys
have a real config to rebuild from. See `bootstrap.sh --help` and its
own comments for every flag (`--disk`, `--secrets-file`,
`--tailscale-auth-key-file`, `--no-commit`, `--ssh-user`).

For a new host, add it to `hosts` in `flake.nix` first, then bootstrap
with `--hostname <that-name>`.

## Path 2: add to an existing NixOS config

If you already run NixOS somewhere and just want SapoHub added to that
config, import this repo's module — no `services.sapohub = { ... }`
block required:

```nix
# in your existing flake.nix
inputs.sapohub-config.url = "github:Sapo-Dorado/SapoHub-Config";

# in your existing nixosConfigurations.<your-host>
modules = [
  sapohub-config.nixosModules.default
  {
    services.sapohub.deploy = {
      flakeAttr = "<your-host>";
      # This repo (SapoHub-Config) is just a dependency you're
      # importing here — YOUR flake is the outermost one with a real
      # nixosConfigurations.<your-host>, so it's what sapohub-deploy
      # must clone/pull/rebuild. Point this at your own repo, not
      # SapoHub-Config's — sapohub-deploy would otherwise clone/rebuild
      # THIS repo, which doesn't define your host at all.
      repoUrl = "https://github.com/you/your-config-repo";
      # sapohub-config's own pin on SapoHub-2.0 lives in ITS flake.lock,
      # not yours — nix's lockfile model keeps a transitive pin as an
      # override entry in the CONSUMING flake (yours). Reach through it
      # with a dotted path so a plain redeploy still bumps SapoHub-2.0:
      updateInputNames = [ "sapohub-config/sapohub" ];
    };
  }
  # ...your existing modules (fileSystems, boot.loader, hardware, etc.)
];
```

`deploy.flakeAttr` and `deploy.repoUrl` are the two things you must set
yourself — `flakeAttr` has to match whatever you called your own
`nixosConfigurations` attribute, and `repoUrl` has to point at your own
repo, not this one (neither has a default here on purpose, for exactly
this reason — a previous version of this module set `repoUrl` as a
`mkDefault` pointing at itself, which silently broke the very first
real consumer that imported it: `deploy.repoUrl` inherited THIS repo's
URL instead of theirs, and `sapohub-deploy` cloned/rebuilt the wrong
flake). Everything else (module selection, secrets path, the unfree
`claude-code` package) is already wired up by this repo's module and
SapoHub-2.0's own defaults, and can still be overridden by setting
`services.sapohub.*` directly in your config, same as always.
`assistant.browser.enable` similarly isn't set by this module for the
same reason — add it yourself, alongside the block above, if you want
it.

The recommended networking options for an existing box are Tailscale +
HTTPS nginx — add them alongside the block above:

```nix
{ services.sapohub.tailscale.enable = true;
  services.sapohub.nginx.https = true; }
```

`tailscale.enable` installs and starts tailscaled (you still need to run
`tailscale up` once to authenticate if you don't supply an auth key).
`nginx.https = true` enables the nginx reverse proxy on port 443 with
Tailscale-issued TLS certificates — without it nginx only listens on
port 80 and the firewall stays closed.

Before running `nixos-rebuild switch`, create the secrets file on the
target machine (the bootstrap script does this for Path 1, but for an
existing box you do it once by hand):

```sh
sudo mkdir -p /etc/sapohub
sudo sh -c 'echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > /etc/sapohub/secrets.env'
sudo chmod 600 /etc/sapohub/secrets.env
```

Then `nixos-rebuild switch --flake .#<your-host>` however you normally
deploy your own config. Any other secrets (e.g. `GITHUB_TOKEN`) can be
added to `/etc/sapohub/secrets.env` later via `sapohub-set-secret` or
the Settings UI.

## Updating

Once deployed (either path), `/etc/sapohub-config` on the target is a
checkout of this repo (`services.sapohub.deploy.flakePath`). SSH in and
run `sapohub-deploy`, or use the Settings page's Deploy button (which
also syncs UI preferences from Settings back into `sapohub-prefs.nix`
here).
