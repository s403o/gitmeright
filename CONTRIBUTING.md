# Contributing to gitmeright

Thanks for helping. This tool writes to people's `~/.gitconfig` and `~/.ssh`, so the bar
for changes is a little higher than usual — the rules below exist because of specific bugs
that shipped, not out of principle.

## Running the tests

```bash
brew install bats-core shellcheck     # or: apt-get install bats shellcheck
bats test/
shellcheck --severity=style --shell=bash bin/gitmeright install.sh
```

Both must be clean before a PR is ready. **Every test builds its own throwaway `$HOME`** —
running the suite will never touch your real git config or SSH keys. If you write a test
that can, it will be rejected.

## The rules

**1. Assert through `git config`, never `grep`.**

This is the important one. The pre-2.0 test suite had 18 assertions and all of them
checked whether a string appeared in a file. It had an assertion `grep -q "work"
~/.gitconfig` that *passed on exactly the text that constituted a critical bug* — the
string was there, inside a pattern that could never match a real remote.

So: build a fixture repo, give it a remote, and ask git what it resolves to.

```bash
@test "acme remotes resolve to the work identity" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:acme/api.git)
	[ "$(resolved_email "$repo")" = "w@acme.com" ]
}
```

**2. Your test must fail before your fix.** Write it first and watch it go red. A test
that never failed is not testing anything — the old suite had a 28-line email-validation
step whose assertions ran in subshells inside a script with no `set -e`, so a validator
that accepted *every* input still printed ✅ and exited 0.

**3. bash 3.2 is the floor.** macOS ships bash 3.2 and it is in the CI matrix. That rules
out `declare -n`, associative arrays, `${var^^}`, `mapfile`, and `&>>`. Use `printf -v`
for indirect assignment.

**4. Never `eval`, never `sed -i` on generated files.** Both were sources of shipped bugs
— `eval` on prompt input was arbitrary code execution, and GNU-only `sed -i` silently did
nothing on macOS. Write config with `git config -f <file>`, which handles git's quoting
rules for you; a user's name may legitimately contain `&`, `/`, `\` or `"`.

**5. Never destroy user state.** Back up before writing, append rather than replace, and
make sure `uninstall` reverses whatever you added. There is a test asserting that
install-then-uninstall leaves `~/.gitconfig` byte-identical; keep it passing.

**6. Any `# shellcheck disable=` needs a comment saying why.**

## Adding a new check to `doctor`

`doctor` is read-only and must stay that way — there's a test for it. Each check prints
`✓`/`!`/`✗`, a short label, and **a remedy the user can act on**. "SSH key is wrong" is not
a check; "`id_ed25519_work` must be mode 600 — run: `chmod 600 …`" is.

Order matters: check cheap and specific conditions before general ones. Permissions are
checked before readability because `ssh-keygen` refuses to read a world-readable key, and
reporting that as "incomplete pair" sends people chasing the wrong fault.

## Platform claims

If you add a platform to the README, add it to the CI matrix in the same PR. The pre-2.0
README claimed macOS support while CI tested Ubuntu twice — which is why a bug that broke
the tool completely on macOS survived for months.

## Commits and PRs

One logical change per PR, ideally under 200 lines. Commit subject lines only — put the
reasoning in the PR description.
