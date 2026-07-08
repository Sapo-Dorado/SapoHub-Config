# Machine-owned — overwritten by `sapohub-deploy --sync-prefs` (the
# Settings page's Deploy button) whenever there are local UI preference
# changes to sync. Starts empty so the very first `nixos-rebuild switch`,
# before any deploy has run, has something valid to import. Committed to
# git so preferences survive a redeploy onto a new host. Don't hand-edit
# for long-lived changes — anything set directly on
# `services.sapohub.prefs` in flake.nix always wins (this file's values
# are wrapped in `lib.mkDefault`).
{ ... }:
{
  services.sapohub.prefs = { };
}
