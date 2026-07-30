#!/usr/bin/env bash
#
# gitmeright installer.
#
#   curl -fsSL https://raw.githubusercontent.com/s403o/gitmeright/main/install.sh | bash
#
# Installs a single self-contained bash script to ~/.local/bin/gitmeright.
# It does not touch your git config — run `gitmeright init` when you're ready.

set -euo pipefail

REPO="s403o/gitmeright"
REF="${GITMERIGHT_REF:-main}"
PREFIX="${GITMERIGHT_PREFIX:-$HOME/.local/bin}"
TARGET="$PREFIX/gitmeright"
# Set to a local path to install from a checkout instead of downloading.
SOURCE="${GITMERIGHT_SOURCE:-}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
	BOLD=''; GREEN=''; YELLOW=''; RED=''; RESET=''
fi

ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required but not installed."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ -n "$SOURCE" ]; then
	[ -f "$SOURCE" ] || die "GITMERIGHT_SOURCE=$SOURCE does not exist."
	cp "$SOURCE" "$tmp/gitmeright"
else
	url="https://raw.githubusercontent.com/$REPO/$REF/bin/gitmeright"
	printf 'downloading %s\n' "$url"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$tmp/gitmeright" || die "download failed."
	elif command -v wget >/dev/null 2>&1; then
		wget -qO "$tmp/gitmeright" "$url" || die "download failed."
	else
		die "need curl or wget to download."
	fi
fi

# Refuse to clobber something that is not ours.
if [ -e "$TARGET" ] && ! head -5 "$TARGET" 2>/dev/null | grep -q 'gitmeright'; then
	die "$TARGET already exists and was not installed by gitmeright. Move it aside first."
fi

grep -q '^GITMERIGHT_VERSION=' "$tmp/gitmeright" || die "downloaded file does not look like gitmeright."
bash -n "$tmp/gitmeright" || die "downloaded file failed a syntax check — refusing to install."

mkdir -p "$PREFIX"
install -m 0755 "$tmp/gitmeright" "$TARGET" 2>/dev/null || { cp "$tmp/gitmeright" "$TARGET"; chmod 0755 "$TARGET"; }

version=$("$TARGET" --version 2>/dev/null || printf 'unknown')
ok "installed $version to $TARGET"

if command -v shasum >/dev/null 2>&1; then
	printf '  sha256: %s\n' "$(shasum -a 256 "$TARGET" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
	printf '  sha256: %s\n' "$(sha256sum "$TARGET" | awk '{print $1}')"
fi

case ":$PATH:" in
	*":$PREFIX:"*) ;;
	*)
		warn "$PREFIX is not on your PATH. Add this to your shell profile:"
		# shellcheck disable=SC2016  # $PATH must stay literal — this is a line
		# for the user to paste into their shell profile, not one to expand here.
		printf '\n    export PATH="%s:$PATH"\n\n' "$PREFIX"
		;;
esac

printf '\n%snext:%s  gitmeright init\n' "$BOLD" "$RESET"
printf 'nothing in your git config has been changed yet.\n'
