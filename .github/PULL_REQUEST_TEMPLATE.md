## What and why

<!-- What was broken or missing, and what this changes. -->

## Checklist

- [ ] `bats test/` passes locally
- [ ] `shellcheck --severity=style --shell=bash bin/gitmeright install.sh` is clean
- [ ] New behaviour has a test that asserts through `git config` on a fixture repo — not `grep`
- [ ] I confirmed that test **fails without my change**
- [ ] bash 3.2 compatible (no `declare -n`, associative arrays, `${var^^}`, `mapfile`)
- [ ] If this touches install/uninstall: `~/.gitconfig` is still restored byte-for-byte
- [ ] README / CHANGELOG updated if user-facing
