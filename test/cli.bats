#!/usr/bin/env bats
#
# The command surface: diagnosis (whoami/doctor), the guard hook, and flags.

load helper

setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

# --- whoami ------------------------------------------------------------------

@test "whoami names the matching profile and exits 0" {
	gmr add work --name "Work W" --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:acme/api.git)

	run bash -c "cd '$repo' && '$GITMERIGHT' whoami"
	[ "$status" -eq 0 ]
	[[ "$output" == *"work"* ]]
	[[ "$output" == *"w@acme.com"* ]]
}

@test "whoami explains WHY nothing matched and exits non-zero" {
	gmr add work --name "Work W" --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:someoneelse/api.git)

	run bash -c "cd '$repo' && '$GITMERIGHT' whoami"
	[ "$status" -ne 0 ]
	[[ "$output" == *"none matched"* ]]
	[[ "$output" == *"org does not"* ]]      # the specific reason, not just "no match"
	[[ "$output" == *"deliberate"* ]]        # explains the loud failure is intended
}

@test "whoami distinguishes a wrong host from a wrong org" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@gitlab.com:acme/api.git)

	run bash -c "cd '$repo' && '$GITMERIGHT' whoami"
	[[ "$output" == *"different host"* ]]
}

@test "whoami fails cleanly outside a git repository" {
	run bash -c "cd '$SANDBOX' && '$GITMERIGHT' whoami"
	[ "$status" -ne 0 ]
	[[ "$output" == *"not inside a git repository"* ]]
}

@test "whoami never writes anything" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:acme/api.git)
	touch "$SANDBOX/.stamp"; sleep 1
	bash -c "cd '$repo' && '$GITMERIGHT' whoami" >/dev/null
	[ -z "$(find "$GMR_DIR" -newer "$SANDBOX/.stamp" 2>/dev/null)" ]
}

# --- doctor ------------------------------------------------------------------

@test "doctor passes on a healthy install" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	run "$GITMERIGHT" doctor
	[ "$status" -eq 0 ]
	[[ "$output" == *"all checks passed"* ]]
}

@test "doctor is useful when gitmeright was never installed" {
	run "$GITMERIGHT" doctor
	[ "$status" -ne 0 ]
	[[ "$output" == *"gitmeright init"* ]]
}

@test "doctor reports the git version" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	run "$GITMERIGHT" doctor
	[[ "$output" == *"git version"* ]]
}

@test "doctor never writes anything" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	cp "$HOME/.gitconfig" "$SANDBOX/before"
	"$GITMERIGHT" doctor >/dev/null || true
	run cmp "$SANDBOX/before" "$HOME/.gitconfig"
	[ "$status" -eq 0 ]
}

# --- list / remove -----------------------------------------------------------

@test "list is helpful when there are no profiles" {
	run "$GITMERIGHT" list
	[ "$status" -eq 0 ]
	[[ "$output" == *"gitmeright init"* ]]
}

@test "list shows every profile" {
	gmr add one --name A --email a@x.com --host github.com --org o1 --no-key
	gmr add two --name B --email b@x.com --host gitlab.com --org o2 --no-key
	run "$GITMERIGHT" list
	[[ "$output" == *"one"* ]]
	[[ "$output" == *"a@x.com"* ]]
	[[ "$output" == *"two"* ]]
	[[ "$output" == *"gitlab.com/o2"* ]]
}

@test "adding a duplicate label is refused" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	run gmr add work --name W2 --email w2@acme.com --host github.com --org acme2 --no-key
	[ "$status" -ne 0 ]
	[[ "$output" == *"already exists"* ]]
	[ "$(resolved_email "$(make_repo r git@github.com:acme/x.git)")" = "w@acme.com" ]
}

@test "removing a profile that does not exist is refused" {
	run gmr remove nope
	[ "$status" -ne 0 ]
}

# --- guard hook --------------------------------------------------------------

@test "guard blocks a commit in a repo matching no profile" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo outside git@github.com:stranger/x.git)
	git -C "$repo" config user.name T
	git -C "$repo" config user.email t@t.com   # so only the hook can block

	bash -c "cd '$repo' && '$GITMERIGHT' guard --install" >/dev/null
	printf 'x\n' > "$repo/f"; git -C "$repo" add f

	run bash -c "cd '$repo' && PATH='$(dirname "$GITMERIGHT")':\$PATH git commit -m nope"
	[ "$status" -ne 0 ]
	[[ "$output" == *"matches no identity profile"* ]]
}

@test "guard allows a commit in a matching repo" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo inside git@github.com:acme/x.git)

	bash -c "cd '$repo' && '$GITMERIGHT' guard --install" >/dev/null
	printf 'x\n' > "$repo/f"; git -C "$repo" add f

	run bash -c "cd '$repo' && PATH='$(dirname "$GITMERIGHT")':\$PATH git commit -m yes"
	[ "$status" -eq 0 ]
}

@test "guard is bypassable with --no-verify" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo outside git@github.com:stranger/x.git)
	git -C "$repo" config user.name T
	git -C "$repo" config user.email t@t.com

	bash -c "cd '$repo' && '$GITMERIGHT' guard --install" >/dev/null
	printf 'x\n' > "$repo/f"; git -C "$repo" add f

	run bash -c "cd '$repo' && PATH='$(dirname "$GITMERIGHT")':\$PATH git commit --no-verify -m forced"
	[ "$status" -eq 0 ]
}

@test "guard refuses to clobber an existing pre-commit hook" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:acme/x.git)
	mkdir -p "$repo/.git/hooks"
	printf '#!/bin/sh\necho mine\n' > "$repo/.git/hooks/pre-commit"
	chmod +x "$repo/.git/hooks/pre-commit"

	run bash -c "cd '$repo' && '$GITMERIGHT' guard --install"
	[ "$status" -ne 0 ]
	[[ "$output" == *"not overwriting"* ]]
	grep -q 'echo mine' "$repo/.git/hooks/pre-commit"
}

@test "guard --remove takes its own hook away" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	repo=$(make_repo r git@github.com:acme/x.git)
	bash -c "cd '$repo' && '$GITMERIGHT' guard --install" >/dev/null
	bash -c "cd '$repo' && '$GITMERIGHT' guard --remove" >/dev/null
	[ ! -f "$repo/.git/hooks/pre-commit" ]
}

# --- flags -------------------------------------------------------------------

@test "--help and --version work and exit 0" {
	run "$GITMERIGHT" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"whoami"* ]]
	[[ "$output" == *"doctor"* ]]

	run "$GITMERIGHT" --version
	[ "$status" -eq 0 ]
	[[ "$output" == *"gitmeright"* ]]
}

@test "an unknown command or flag fails with usage" {
	run "$GITMERIGHT" frobnicate
	[ "$status" -ne 0 ]
	[[ "$output" == *"unknown command"* ]]
}

@test "--non-interactive fails loudly instead of blocking on a prompt" {
	run "$GITMERIGHT" add work --non-interactive --yes
	[ "$status" -ne 0 ]
	[[ "$output" == *"non-interactive"* ]]
}

# --- tweaks are opt-in -------------------------------------------------------

# `git config --global --get` does not recurse into an include-of-an-include,
# so it reports "unset" whether or not the tweaks are active — an assertion that
# cannot fail. Probe from a real repo instead, like every other test here.
tweak_active() { git -C "$(make_repo tweakprobe)" config --get pull.rebase 2>/dev/null || printf ''; }

@test "opinionated git defaults are NOT applied unless asked for" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	[ -z "$(tweak_active)" ]
}

@test "tweaks --install applies them and --remove reverses them" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	"$GITMERIGHT" tweaks --install >/dev/null
	[ "$(tweak_active)" = "true" ]

	"$GITMERIGHT" tweaks --remove >/dev/null
	[ -z "$(tweak_active)" ]
}

@test "tweaks survive a regenerate" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	"$GITMERIGHT" tweaks --install >/dev/null
	gmr regenerate
	[ "$(tweak_active)" = "true" ]
}

@test "uninstall reverses the tweaks too" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	"$GITMERIGHT" tweaks --install >/dev/null
	gmr uninstall
	[ -z "$(tweak_active)" ]
}
