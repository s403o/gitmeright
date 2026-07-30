# Shared setup for the gitmeright test suite.
#
# Every test runs against a throwaway $HOME. Nothing here may touch the real
# one — the tool writes to ~/.gitconfig and ~/.ssh, and a suite that eats the
# contributor's own git config is a suite nobody runs twice.

setup_sandbox() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
	GITMERIGHT="$REPO_ROOT/bin/gitmeright"

	# pwd -P throughout: `gitdir:` matches the repo's resolved path, and macOS
	# puts temp dirs behind the /var -> /private/var symlink.
	SANDBOX="$(cd "$(mktemp -d)" && pwd -P)"
	export HOME="$SANDBOX"
	export XDG_CONFIG_HOME="$SANDBOX/.config"

	# Keep the runner's git identity and any CI-wide config out of the way.
	export GIT_CONFIG_NOSYSTEM=1
	unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL || true

	GMR_DIR="$XDG_CONFIG_HOME/gitmeright"
	STATE="$GMR_DIR/profiles"
	FRAGMENT="$GMR_DIR/gitconfig"
}

teardown_sandbox() {
	[ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
	return 0
}

# Run the CLI. Never interactive: tests supply every value as a flag.
gmr() {
	"$GITMERIGHT" "$@" --yes --non-interactive
}

# A repo with the given remote (or none), inside the sandbox.
make_repo() {
	local path="$SANDBOX/$1" remote="${2:-}"
	mkdir -p "$path"
	git -C "$path" init -q
	[ -n "$remote" ] && git -C "$path" remote add origin "$remote"
	printf '%s' "$path"
}

# The assertion that matters: what identity does git actually resolve here?
resolved_email() { git -C "$1" config user.email 2>/dev/null || printf ''; }
resolved_name()  { git -C "$1" config user.name  2>/dev/null || printf ''; }
