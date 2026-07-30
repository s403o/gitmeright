#!/usr/bin/env bats
#
# The command surface: diagnosis (whoami/doctor), the guard hook, and flags.

load helper

setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

# --- whoami ------------------------------------------------------------------

# --- doctor ------------------------------------------------------------------

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

# --- flags -------------------------------------------------------------------

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
