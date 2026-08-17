#!/bin/sh
#
# workflows.sh — hold the workflows themselves to the rules that keep a public
# repository's CI from becoming the way into it.
#
#   .github/checks/workflows.sh
#
# Everything here is a rule about the workflow file, not about what the project
# does, and every one of them is a way repositories have actually been taken
# over:
#
#   1. no pull_request_target. It runs the workflow from the base branch with a
#      token that can write to this repository and the secrets to go with it,
#      for a pull request opened by anybody with a fork. One `checkout` of the
#      pull request head under that trigger and a stranger's code is running
#      with write access.
#   2. permissions declared at the top of the file. The default is whatever the
#      repository setting says, which changes under you; a workflow that says
#      `contents: read` keeps saying it. write-all is refused outright.
#   3. no ${{ }} inside a run: script. GitHub substitutes the expression into
#      the script before the shell sees it, so a pull request title, branch
#      name or issue body — all of them written by whoever opened it — becomes
#      shell source. Through `env:` the same value arrives as data the shell
#      never parses. pr-title.yml has this rule written on it in full.
#   4. any action pinned to a full commit SHA, and only actions published by
#      GitHub itself. A tag is a name its owner can move onto different code
#      after you read it; a SHA is the code you read. This repository's
#      standing rule is to write the step in shell instead — see the header of
#      pr-title.yml — so this check is the backstop for the day somebody
#      decides an action really is warranted.
#
# What it deliberately does not do: it is not a workflow schema validator. It
# does not know which keys are legal, whether `runs-on` names a real image, or
# whether the YAML means what its author thought. lint.sh proves the file
# parses; GitHub rejects a workflow whose shape it cannot use; this file is
# about the handful of mistakes that are dangerous rather than merely wrong.

status=0

# The action owners this repository will run. GitHub's own namespaces, and only
# because they are already trusted with the code and the token — adding to this
# list means deciding to trust somebody else's release process too.
trusted_owners='actions github'

report() {
	if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
		printf '::error file=%s,line=%s::%s\n' "$1" "$2" "$3"
	else
		printf '%s:%s: %s\n' "$1" "$2" "$3"
	fi
	status=1
}

annotate_findings() {
	while IFS=: read -r file line message; do
		[ -n "$file" ] || continue
		report "$file" "$line" "${message# }"
	done
}

workflows=$(git ls-files '.github/workflows/*.yml' '.github/workflows/*.yaml')

if [ -z "$workflows" ]; then
	echo "ok: no workflows to check"
	exit 0
fi

while IFS= read -r path; do
	[ -n "$path" ] || continue

	triggers=$(grep -n 'pull_request_target' "$path")
	if [ -n "$triggers" ]; then
		while IFS=: read -r lineno _; do
			report "$path" "$lineno" "pull_request_target runs with a write token and this repository's secrets for a pull request from any fork. Use pull_request, which runs from the fork's own branch with a read token."
		done <<TRIGGERS
$triggers
TRIGGERS
	fi

	if ! grep -q '^permissions:' "$path"; then
		report "$path" 1 "no top-level permissions: block. Without one the job gets whatever the repository default happens to be that week; say what this workflow needs, which is usually contents: read."
	fi

	broad=$(grep -n 'permissions:[[:blank:]]*write-all' "$path")
	if [ -n "$broad" ]; then
		while IFS=: read -r lineno _; do
			report "$path" "$lineno" "permissions: write-all hands every scope to every step. List the scopes this workflow actually needs."
		done <<BROAD
$broad
BROAD
	fi

	# ${{ }} inside a run: script. Written in awk because it is a question
	# about the block a line belongs to, and the answer is the indentation:
	# everything indented further than the `run:` key is part of its script.
	interpolations=$(awk -v file="$path" '
		function indent_of(text) {
			match(text, /^ */)
			return RLENGTH
		}

		in_run {
			if ($0 ~ /^[[:space:]]*$/) { next }
			if (indent_of($0) > run_indent) {
				if ($0 ~ /\$\{\{/) {
					print file ":" NR ": a ${{ }} expression is substituted into this run: script before the shell reads it. Pass the value through env: and use $NAME."
				}
				next
			}
			in_run = 0
		}

		/^[[:space:]]*-?[[:space:]]*run:/ {
			run_indent = indent_of($0)
			rest = $0
			sub(/^[^:]*run:[[:space:]]*/, "", rest)
			if (rest == "" || rest ~ /^[|>]/) {
				in_run = 1
			} else if (rest ~ /\$\{\{/) {
				print file ":" NR ": a ${{ }} expression is substituted into this run: script before the shell reads it. Pass the value through env: and use $NAME."
			}
		}
	' "$path")
	if [ -n "$interpolations" ]; then
		annotate_findings <<INTERPOLATIONS
$interpolations
INTERPOLATIONS
	fi

	uses=$(grep -n '^[[:space:]]*-\{0,1\}[[:space:]]*uses:' "$path")
	if [ -n "$uses" ]; then
		while IFS=: read -r lineno text; do
			value=${text#*uses:}
			value=${value%%#*}
			# Strip the surrounding whitespace and any quotes.
			value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//')

			case $value in
			./* | ../*)
				# A path into this repository. It is this repository's code,
				# reviewed like the rest of it.
				continue
				;;
			docker://*)
				report "$path" "$lineno" "runs a container image from a registry: $value. The tag can be repointed at different code after you read it."
				continue
				;;
			esac

			owner=${value%%/*}
			ref=${value##*@}

			trusted=no
			for candidate in $trusted_owners; do
				[ "$candidate" = "$owner" ] && trusted=yes
			done

			if [ "$trusted" = no ]; then
				report "$path" "$lineno" "uses a third-party action: $value. Write the step in shell, or if it genuinely needs an action, one published by GitHub itself."
			fi

			if ! printf '%s' "$ref" | grep -Eq '^[0-9a-f]{40}$'; then
				report "$path" "$lineno" "action is not pinned to a commit: $value. A tag points wherever its owner last moved it; pin the 40-character SHA and put the version in a comment beside it."
			fi
		done <<USES
$uses
USES
	fi
done <<EOF
$workflows
EOF

if [ "$status" -eq 0 ]; then
	printf 'ok: %s\n' "$(printf '%s' "$workflows" | tr '\n' ' ')"
fi

exit "$status"
