# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 2.x | ✅ |
| 1.x (`setup.sh`) | ❌ — see below |

## If you are on 1.x, please upgrade

The pre-2.0 `setup.sh` had two issues worth calling out directly:

- It ran `cp .gitconfig ~/.gitconfig` with **no backup and no confirmation**, destroying
  the user's global git config — including credential helpers and signing keys.
- It used `eval` on unsanitised prompt input, which is arbitrary code execution. Reachable
  from all nine prompts, and relevant to anyone piping an answers file into it
  non-interactively.

Both are fixed in 2.0. There is no patch for 1.x; upgrade instead.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Use [GitHub's private vulnerability reporting](https://github.com/s403o/gitmeright/security/advisories/new)
on this repository. Include what you can reproduce, on which OS and git version.

Expect an acknowledgement within a few days. Since gitmeright is a small volunteer
project, please allow reasonable time for a fix before public disclosure.

## What is in scope

gitmeright writes to `~/.gitconfig`, `~/.config/gitmeright/` and `~/.ssh/`, and generates
SSH keys. Things we care about:

- Anything that executes user-supplied input rather than storing it.
- Anything that writes outside those paths, or follows a symlink out of them.
- Anything that weakens key permissions, or causes ssh to authenticate as an unintended
  account.
- Anything that destroys user config without a restorable backup.

Note that generated keys are **passphrase-less by default** — this is stated at generation
time and is a deliberate convenience tradeoff, not a vulnerability. Use `--passphrase` if
you want otherwise.
