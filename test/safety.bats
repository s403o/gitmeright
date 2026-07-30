#!/usr/bin/env bats
#
# Regressions for the destructive and injection defects in the old setup.sh
# (audit C-01 … C-04, H-02, H-04). Each test names the bug it guards.

load helper

setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

seed_existing_config() {
	cat > "$HOME/.gitconfig" <<-'EOF'
		[user]
			name = Existing User
			email = existing@example.com
		[alias]
			super = log --oneline --graph
		[credential]
			helper = osxkeychain
		[core]
			excludesfile = ~/.gitignore_global
	EOF
	cp "$HOME/.gitconfig" "$HOME/.gitconfig.original"
}

# --- C-03: the old script ran `cp .gitconfig ~/.gitconfig` --------------------

@test "C-03: installing preserves everything already in ~/.gitconfig" {
	seed_existing_config
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key

	[ "$(git config --global --get alias.super)"       = "log --oneline --graph" ]
	[ "$(git config --global --get credential.helper)" = "osxkeychain" ]
	[ "$(git config --global --get core.excludesfile)" = "~/.gitignore_global" ]
	[ "$(git config --global --get user.name)"         = "Existing User" ]
}

@test "C-03: a timestamped backup is written before ~/.gitconfig is touched" {
	seed_existing_config
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key

	backup=$(find "$HOME" -maxdepth 1 -name '.gitconfig.gitmeright.bak.*' | head -1)
	[ -n "$backup" ]
	run cmp -s "$backup" "$HOME/.gitconfig.original"
	[ "$status" -eq 0 ]
}

@test "C-03: uninstall restores ~/.gitconfig byte-for-byte" {
	seed_existing_config
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	gmr uninstall

	run cmp "$HOME/.gitconfig.original" "$HOME/.gitconfig"
	[ "$status" -eq 0 ]
}

@test "C-03: uninstall works when the include is not the last block" {
	seed_existing_config
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	printf '\n[color]\n\tui = auto\n' >> "$HOME/.gitconfig"
	gmr uninstall

	[ "$(git config --global --get color.ui)" = "auto" ]
	[ "$(git config --global --get alias.super)" = "log --oneline --graph" ]
	run grep -c 'gitmeright' "$HOME/.gitconfig"
	[ "$output" = "0" ]
}

@test "installing twice leaves exactly one include and an identical config" {
	seed_existing_config
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	cp "$HOME/.gitconfig" "$HOME/.after-first"
	gmr regenerate
	gmr regenerate

	run cmp "$HOME/.after-first" "$HOME/.gitconfig"
	[ "$status" -eq 0 ]
	[ "$(grep -c '^\[include\]' "$HOME/.gitconfig")" = "1" ]
}

# --- C-04: `eval "$varname=\"$input\""` was arbitrary code execution ----------

@test "C-04: a name containing shell metacharacters does not execute" {
	gmr add pwn --name 'x"; touch $HOME/PWNED; #' --email a@b.com \
		--host github.com --org o --no-key
	[ ! -e "$HOME/PWNED" ]
}

# --- H-02: user input was interpolated into sed replacement text -------------

@test "H-02: a name with & / \\ and quotes round-trips exactly" {
	tricky='Ben & Jerry O/Brien \ "quoted"'
	gmr add t --name "$tricky" --email ben@example.com \
		--host gitlab.com --org acme --no-key
	repo=$(make_repo r git@gitlab.com:acme/x.git)
	[ "$(resolved_name "$repo")" = "$tricky" ]
}

@test "H-02: an email with a plus tag survives" {
	gmr add t --name N --email 'user.name+tag@sub.domain.co.uk' \
		--host github.com --org o --no-key
	repo=$(make_repo r git@github.com:o/x.git)
	[ "$(resolved_email "$repo")" = "user.name+tag@sub.domain.co.uk" ]
}

# --- H-04: 17 unquoted expansions used as filenames --------------------------

@test "H-04: labels that are unsafe as filenames are rejected, touching nothing" {
	for bad in "my work" "../evil" "-rf" "a.b" "we/ird"; do
		run gmr add "$bad" --name N --email a@b.com --host github.com --org o --no-key
		[ "$status" -ne 0 ]
	done
	[ ! -e "$STATE" ]
	[ ! -e "$HOME/.gitconfig" ]
}

@test "invalid emails and hosts are rejected" {
	run gmr add a --name N --email 'not-an-email' --host github.com --org o --no-key
	[ "$status" -ne 0 ]
	run gmr add b --name N --email 'user@' --host github.com --org o --no-key
	[ "$status" -ne 0 ]
	run gmr add c --name N --email a@b.com --host 'not a host' --org o --no-key
	[ "$status" -ne 0 ]
	[ ! -e "$STATE" ]
}

# --- H-06 / GMR-404: --dry-run --------------------------------------------

@test "--dry-run writes absolutely nothing" {
	run "$GITMERIGHT" add work --name W --email w@acme.com \
		--host github.com --org acme --no-key --yes --non-interactive --dry-run
	[ "$status" -eq 0 ]
	[[ "$output" == *"would write"* ]]

	[ ! -e "$HOME/.gitconfig" ]
	[ ! -e "$GMR_DIR" ]
	[ -z "$(find "$HOME" -mindepth 1 2>/dev/null)" ]
}

# --- C-01: the old script could not fail -------------------------------------

# --- M-01: a half-generated key pair was reported as success -----------------

@test "M-05: ~/.ssh is created as 700 and keys as 600" {
	gmr add work --name W --email w@acme.com --host github.com --org acme
	run find "$HOME/.ssh" -maxdepth 0 -perm 700
	[ -n "$output" ]
	run find "$HOME/.ssh/id_ed25519_work" -maxdepth 0 -perm 600
	[ -n "$output" ]
}

# --- key material is never destroyed ----------------------------------------

@test "an existing key is reused, never overwritten" {
	mkdir -p "$HOME/.ssh"
	ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_work" -N "" -q -C precious
	before=$(cat "$HOME/.ssh/id_ed25519_work")
	gmr add work --name W --email w@acme.com --host github.com --org acme
	[ "$(cat "$HOME/.ssh/id_ed25519_work")" = "$before" ]
}

@test "uninstall leaves ssh keys alone" {
	gmr add work --name W --email w@acme.com --host github.com --org acme
	gmr uninstall
	[ -f "$HOME/.ssh/id_ed25519_work" ]
}
