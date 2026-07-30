#!/usr/bin/env bats
#
# The product promise: given a repo, does git resolve the right identity?
#
# Every assertion here goes through `git config`, never `grep`. The old suite
# grepped generated files and passed on exactly the text that constituted the
# bug it was supposed to catch (audit C-06).

load helper

setup()    { setup_sandbox; }
teardown() { teardown_sandbox; }

@test "ssh remote resolves to the matching profile" {
	gmr add personal --name "Personal P" --email personal@example.com \
		--host github.com --org alice --no-key
	repo=$(make_repo r git@github.com:alice/thing.git)
	[ "$(resolved_email "$repo")" = "personal@example.com" ]
	[ "$(resolved_name  "$repo")" = "Personal P" ]
}

@test "https remote resolves to the same profile as the ssh form" {
	gmr add personal --name "Personal P" --email personal@example.com \
		--host github.com --org alice --no-key
	repo=$(make_repo r https://github.com/alice/thing.git)
	[ "$(resolved_email "$repo")" = "personal@example.com" ]
}

@test "ssh:// url form resolves" {
	gmr add personal --name "Personal P" --email personal@example.com \
		--host github.com --org alice --no-key
	repo=$(make_repo r ssh://git@github.com/alice/thing.git)
	[ "$(resolved_email "$repo")" = "personal@example.com" ]
}

@test "gitdir rule resolves a repo that has no remote at all" {
	gmr add work --name "Work W" --email work@acme.com \
		--host github.com --org acme --gitdir "$SANDBOX/work" --no-key
	repo=$(make_repo work/fresh)
	[ "$(resolved_email "$repo")" = "work@acme.com" ]
}

@test "a repo matching no profile gets NO identity — it must fail loudly" {
	gmr add personal --name "Personal P" --email personal@example.com \
		--host github.com --org alice --no-key
	repo=$(make_repo r git@github.com:someone-else/thing.git)

	[ -z "$(resolved_email "$repo")" ]

	# and git must actually refuse the commit
	printf 'x\n' > "$repo/f"
	git -C "$repo" add f
	run git -C "$repo" commit -m "should not be possible"
	[ "$status" -ne 0 ]
}

@test "the right profile wins when several exist" {
	gmr add personal --name P --email p@example.com --host github.com --org alice --no-key
	gmr add work     --name W --email w@acme.com    --host github.com --org acme  --no-key
	gmr add side     --name S --email s@lab.io      --host gitlab.com --org lab   --no-key

	[ "$(resolved_email "$(make_repo a git@github.com:alice/x.git)")" = "p@example.com" ]
	[ "$(resolved_email "$(make_repo b git@github.com:acme/y.git)")"  = "w@acme.com" ]
	[ "$(resolved_email "$(make_repo c git@gitlab.com:lab/z.git)")"   = "s@lab.io" ]
}

@test "a similarly-named org does not match by prefix" {
	gmr add work --name W --email w@acme.com --host github.com --org acme --no-key
	# `acme-evil` must not be caught by the `acme/**` rule
	repo=$(make_repo r git@github.com:acme-evil/x.git)
	[ -z "$(resolved_email "$repo")" ]
}

@test "sshCommand carries IdentitiesOnly=yes" {
	gmr add work --name W --email w@acme.com --host github.com --org acme
	repo=$(make_repo r git@github.com:acme/x.git)
	run git -C "$repo" config core.sshCommand
	[ "$status" -eq 0 ]
	[[ "$output" == *"IdentitiesOnly=yes"* ]]
}

@test "five profiles: removing the middle one leaves the rest resolving" {
	for n in one two three four five; do
		gmr add "$n" --name "N $n" --email "$n@example.com" \
			--host github.com --org "org-$n" --no-key
	done
	gmr remove three

	[ "$(resolved_email "$(make_repo a git@github.com:org-one/x.git)")"   = "one@example.com" ]
	[ "$(resolved_email "$(make_repo b git@github.com:org-two/x.git)")"   = "two@example.com" ]
	[ -z  "$(resolved_email "$(make_repo c git@github.com:org-three/x.git)")" ]
	[ "$(resolved_email "$(make_repo d git@github.com:org-four/x.git)")"  = "four@example.com" ]
	[ "$(resolved_email "$(make_repo e git@github.com:org-five/x.git)")"  = "five@example.com" ]
}
