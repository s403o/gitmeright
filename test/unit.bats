#!/usr/bin/env bats
#
# Direct tests of the real internal functions — sourced, never re-implemented.
# The old CI pasted a copy of the email regex into a generated file and tested
# the copy, so the copy could pass while the original was broken (audit H-11).

load helper

setup() {
	setup_sandbox
	GITMERIGHT_LIB=1 source "$GITMERIGHT"
}
teardown() { teardown_sandbox; }

# --- C-04: assignment must not evaluate its input ----------------------------

@test "C-04: the source contains no eval at all" {
	run grep -nE '(^|[^[:alnum:]_])eval[[:space:]]' "$GITMERIGHT"
	[ "$status" -ne 0 ]
}

@test "C-04: setvar stores a payload literally instead of executing it" {
	payload='x"; touch '"$HOME"'/PWNED; #'
	setvar TARGET "$payload"
	[ ! -e "$HOME/PWNED" ]
	[ "$TARGET" = "$payload" ]
}

@test "C-04: setvar handles backticks and command substitution literally" {
	setvar T 'a`touch '"$HOME"'/BACKTICK`b'
	[ ! -e "$HOME/BACKTICK" ]
	setvar U 'a$(touch '"$HOME"'/SUBST)b'
	[ ! -e "$HOME/SUBST" ]
}

@test "C-04: setvar refuses a variable name that is not an identifier" {
	run setvar '1bad; touch /tmp/x' value
	[ "$status" -ne 0 ]
}

# --- the real email validator (GMR-203) --------------------------------------

@test "validate_email accepts valid addresses" {
	for good in \
		test@example.com \
		user.name+tag@domain.co.uk \
		123@domain.com \
		a@b.io \
		first.last@sub.domain.example.org
	do
		run validate_email "$good"
		[ "$status" -eq 0 ] || { echo "rejected valid: $good"; return 1; }
	done
}

@test "validate_email rejects invalid addresses" {
	for bad in \
		invalid-email \
		@domain.com \
		user@ \
		user.domain.com \
		user@example \
		"" \
		"two words@x.com" \
		"user@@x.com"
	do
		run validate_email "$bad"
		[ "$status" -ne 0 ] || { echo "accepted invalid: $bad"; return 1; }
	done
}

# --- labels become filenames and config subsections --------------------------

@test "validate_label accepts safe labels and rejects unsafe ones" {
	for good in personal work-2 my_client a1; do
		run validate_label "$good"; [ "$status" -eq 0 ] || { echo "rejected: $good"; return 1; }
	done
	for bad in "" "my work" "../evil" "-rf" "a.b" "we/ird" '$(id)' "a;b"; do
		run validate_label "$bad"; [ "$status" -ne 0 ] || { echo "accepted: $bad"; return 1; }
	done
}

@test "validate_host rejects things that are not hostnames" {
	run validate_host github.com;     [ "$status" -eq 0 ]
	run validate_host git.acme.co.uk; [ "$status" -eq 0 ]
	run validate_host "not a host";   [ "$status" -ne 0 ]
	run validate_host "localhost";    [ "$status" -ne 0 ]
	run validate_host "";             [ "$status" -ne 0 ]
}

# --- git version comparison must be numeric (M-06) ---------------------------

@test "git_version_num compares numerically, not lexically" {
	# the classic trap: "2.9" > "2.10" as strings
	stub() { printf 'git version %s\n' "$1"; }
	git() { stub "$STUBBED"; }

	STUBBED=2.9.0;  local v29;  v29=$(git_version_num)
	STUBBED=2.10.0; local v210; v210=$(git_version_num)
	STUBBED=2.36.0; local v236; v236=$(git_version_num)
	STUBBED=2.48.1; local v248; v248=$(git_version_num)

	[ "$v29"  -lt "$v210" ]
	[ "$v210" -lt "$v236" ]
	[ "$v236" -lt "$v248" ]
	[ "$v236" -eq "$GIT_MIN_HASCONFIG" ]
}

@test "supports_hasconfig is false below git 2.36 and true at or above" {
	git() { printf 'git version %s\n' "$STUBBED"; }

	STUBBED=2.30.2; run supports_hasconfig; [ "$status" -ne 0 ]
	STUBBED=2.35.9; run supports_hasconfig; [ "$status" -ne 0 ]
	STUBBED=2.36.0; run supports_hasconfig; [ "$status" -eq 0 ]
	STUBBED=2.48.1; run supports_hasconfig; [ "$status" -eq 0 ]
}

@test "require_git refuses a git older than 2.13" {
	git() { printf 'git version %s\n' "$STUBBED"; }
	STUBBED=2.10.0
	run require_git
	[ "$status" -ne 0 ]
	[[ "$output" == *"2.13"* ]]
}

# --- gitdir normalisation (the symlink trap) ---------------------------------

@test "normalize_dir expands ~ and always ends in a slash" {
	[ "$(normalize_dir '~')"      = "$(cd "$HOME" && pwd -P)/" ]
	[ "$(normalize_dir '')"       = "" ]
	result=$(normalize_dir "$HOME/anything")
	[ "${result: -1}" = "/" ]
}

@test "normalize_dir resolves a path whose leaf does not exist yet" {
	# people configure ~/work before creating it
	result=$(normalize_dir "$HOME/notyet/deeper")
	[ "$result" = "$(cd "$HOME" && pwd -P)/notyet/deeper/" ]
}

@test "normalize_dir resolves symlinks, since gitdir: matches the real path" {
	mkdir -p "$HOME/real"
	ln -s "$HOME/real" "$HOME/link"
	[ "$(normalize_dir "$HOME/link")" = "$(cd "$HOME/real" && pwd -P)/" ]
}

# --- no leftover sed-based templating (C-02) ---------------------------------

@test "C-02: no in-place sed editing survives anywhere in the source" {
	run grep -nE 'sed -i' "$GITMERIGHT"
	[ "$status" -ne 0 ]
}

@test "C-02: the script sets strict mode" {
	run grep -qE '^set -euo pipefail' "$GITMERIGHT"
	[ "$status" -eq 0 ]
}
