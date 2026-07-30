# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — 2026-07-30

A full rewrite. `setup.sh` is gone; `gitmeright` is now a real CLI.

### ⚠️ Breaking

- **`setup.sh` has been removed.** Install v2 and run `gitmeright init`. Your old
  `~/.gitconfig-*` files are no longer used and can be deleted once `gitmeright doctor`
  is green. See *Upgrading* in the README.
- Config now lives under `~/.config/gitmeright/`. `~/.gitconfig` gets **one** appended
  `[include]` line instead of being replaced.
- SSH keys are named `id_ed25519_<profile>` (they were always ed25519; the old
  `id_rsa_*` names were simply wrong).

### Fixed

- **`~/.gitconfig` is no longer destroyed.** The old script ran `cp .gitconfig
  ~/.gitconfig` with no backup, no confirmation and no uninstall, wiping signing keys,
  credential helpers, proxy settings and every alias. v2 backs up to
  `~/.gitconfig.gitmeright.bak.<timestamp>` and only appends.
- **Identities now actually get written on macOS.** Nine of thirteen `sed -i` calls used
  the GNU-only form, which fails on BSD/macOS — so the step that substituted your name and
  email silently did nothing, leaving configs reading `email = you@personal.com` while the
  script printed `✅ Setup complete!`. All `sed` is gone; config is generated via
  `git config -f`.
- **Rules now match the host and org you actually use.** The old script substituted your
  profile *label* into a hardcoded `bitbucket.org`/`gitlab.com` pattern, so unless your
  workspace happened to be named after your label, the rule never fired — silently, since
  git reports no error for an `includeIf` that never matches.
- **`IdentitiesOnly=yes`** is now set on every profile. Without it `ssh -i` merely *adds*
  a key to the candidate list, so a pre-existing default key could authenticate you as the
  wrong account while `git config user.email` showed the right address.
- **No more `eval` on prompt input** (it was arbitrary code execution). Values are stored
  with `printf -v`.
- **Strict mode.** `set -euo pipefail` plus an `ERR` trap replace zero error checks against
  twenty filesystem-mutating commands. The success message is now earned: each profile is
  resolved against a throwaway repo and read back through `git config`.
- Names containing `&`, `/`, `\` or `"` round-trip correctly.
- Labels are validated before becoming filenames.
- `~/.ssh` is forced to `700` and keys to `600`; a half-generated key pair is reported
  instead of being skipped with a green check.
- The orphaned `ssh-agent` (started in a subshell whose environment died with the script)
  is gone.

### Added

- `gitmeright whoami` — which identity this repo resolves to, **and why**, including a
  per-rule reason when nothing matches.
- `gitmeright doctor` — ten health checks git will never warn you about. `--online` asks
  each host which account actually answered.
- `gitmeright add` / `remove` / `list` — unlimited profiles, no fixed ceiling of three.
- `gitmeright guard` — optional pre-commit hook blocking commits in repos that match no
  profile. Refuses to overwrite an existing hook.
- `gitmeright uninstall` — restores `~/.gitconfig` byte-for-byte.
- `gitmeright tweaks` — the opinionated defaults (`pull.rebase` etc.) are now opt-in
  instead of riding along with identity routing.
- Matching by **HTTPS remote** and by **directory (`gitdir:`)**, not just SSH remotes.
  Directory rules work before a remote exists and back to git 2.13.
- Git version gate with a clear message and a `gitdir:` fallback below 2.36.
- Flags: `--dry-run` (writes nothing at all), `--yes`, `--non-interactive`, `--quiet`,
  `--help`, `--version`.
- One-line installer, MIT `LICENSE` (the badge previously linked to nothing), and
  `CONTRIBUTING.md`.

### Changed — testing

- The old suite had 18 assertions, **none** behavioural: it grepped generated files, and
  one assertion passed on exactly the text that constituted a critical bug. A 28-line
  email-validation step could not fail at all — a validator accepting every input still
  exited 0 and printed ✅.
- Replaced with **69 bats tests**, each against a throwaway `$HOME`, each asserting through
  `git config` on a fixture repo. Validated by mutation testing: reintroducing each
  original bug turns the suite red.
- CI matrix went from Ubuntu×2 to **Ubuntu×2 + macOS×2** — the platform the README claimed
  and CI never tested. ShellCheck is now a required gate.

[2.0.0]: https://github.com/s403o/gitmeright/releases/tag/v2.0.0
