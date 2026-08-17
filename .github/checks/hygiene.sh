#!/bin/sh
#
# hygiene.sh — the file-level checks that hold for any repository, whatever it
# is written in. Nothing here knows what this project does, and nothing here
# should learn.
#
# It reads the tracked files of whatever working tree it is run from, so it
# costs nothing to run before pushing:
#
#   .github/checks/hygiene.sh
#
# Under GitHub Actions it prints ::error:: annotations, which land on the line
# they are about in the pull request diff. Anywhere else it prints
# file:line: message, which is the form an editor's quickfix list expects.
#
# What it deliberately does not check:
#
#   - a bare ======= line is not read as a conflict marker. It is a setext
#     heading in Markdown and a divider in half the plain text ever written.
#     The <<<<<<< and >>>>>>> markers of the same conflict are unambiguous, and
#     catching those catches the conflict.
#   - tabs against spaces, indentation width, line length. Those are style, and
#     style is per-repository; this file is not.
#   - file contents against secret patterns. GitHub's push protection does that
#     before the object reaches the remote, which is the last moment at which
#     stopping it means it never leaked at all. A check that runs on a pull
#     request is reading a branch the secret is already public on. The one
#     content-free part of that job worth doing here is the filename check
#     below, which catches the whole-file leaks — a private key, a .env — that
#     push protection's provider patterns do not all cover.

status=0

# The size at which a file stops being source and starts being an attachment.
# The largest thing tracked here is around 70 KiB, so this is not a limit
# anybody meets by writing; it is met by a build output or a screenshot that
# was never meant to be committed.
max_bytes=$((512 * 1024))

# Paths this check is knowingly wrong about. Empty on purpose: add a path with
# a comment saying why the file carries no credential, or, better, do not
# commit the file.
allow_credential_paths=''

report() {
	if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
		printf '::error file=%s,line=%s::%s\n' "$1" "$2" "$3"
	else
		printf '%s:%s: %s\n' "$1" "$2" "$3"
	fi
	status=1
}

is_allowed() {
	for allowed in $allow_credential_paths; do
		[ "$allowed" = "$1" ] && return 0
	done
	return 1
}

tab=$(printf '\t')
bom=$(printf '\357\273\277')

# `git ls-files -s` gives "<mode> <sha> <stage>\t<path>", so the path keeps any
# spaces it has: everything up to the tab is metadata and everything after it
# is the name. Read the list into a here-document rather than a pipe, or the
# loop runs in a subshell and every failure it records is thrown away with it.
files=$(git ls-files -s)

while IFS= read -r line; do
	[ -n "$line" ] || continue

	meta=${line%%"$tab"*}
	path=${line#*"$tab"}
	mode=${meta%% *}

	case $mode in
	120000)
		# A symlink's "contents" are the target path. Nothing below applies.
		continue
		;;
	160000)
		# A submodule. Committing one is a decision, not an accident, and it
		# has no file here to check.
		continue
		;;
	esac

	base=${path##*/}

	# Whole files that are credentials by convention. A .env or an id_rsa is
	# never committed on purpose, and unlike a leaked token in a source file
	# there is nothing to weigh up: the name alone is the finding.
	if ! is_allowed "$path"; then
		case $base in
		.env.example | .env.sample | .env.template | .env.dist) ;;
		.env | .env.?* | id_rsa | id_dsa | id_ecdsa | id_ed25519 | \
			.netrc | .npmrc | .pypirc | .pgpass | .htpasswd | \
			*.pem | *.key | *.p12 | *.pfx | *.jks | *.keystore)
			report "$path" 1 "$base is a credential file by convention; it should not be tracked. Rotate whatever is in it, remove it from history, and add it to .gitignore."
			;;
		esac
	fi

	size=$(wc -c <"$path")
	if [ "$size" -gt "$max_bytes" ]; then
		report "$path" 1 "$size bytes; the limit is $max_bytes. Large files stay in the history of every clone forever — keep it out of git, or say why it belongs."
	fi

	# git calls a blob binary when it finds a NUL byte in it, and so does this.
	# Binary files get no line-ending, newline or whitespace check, because
	# those bytes mean nothing in them.
	unstripped=$(tr -d '\000' <"$path" | wc -c)
	if [ "$size" -ne "$unstripped" ]; then
		report "$path" 1 "binary file. A diff cannot show it, a review cannot read it and every version of it is kept whole. Commit the source it was built from."
		continue
	fi

	# An empty file has no first line, no last byte and nothing to say.
	[ "$size" -gt 0 ] || continue

	IFS= read -r first <"$path"

	case $first in
	"$bom"*)
		report "$path" 1 "starts with a UTF-8 byte order mark. It is invisible in an editor and breaks every tool that expects the first byte to be the first byte — a shebang, a TOML key, a YAML document marker."
		;;
	esac

	case $first in
	'#!'*)
		[ "$mode" = "100755" ] || report "$path" 1 "has a shebang but is not executable (mode $mode). Run: git update-index --chmod=+x '$path'"
		;;
	*)
		[ "$mode" != "100755" ] || report "$path" 1 "is executable (mode $mode) but has no shebang. Run: git update-index --chmod=-x '$path'"
		;;
	esac

	# Command substitution strips trailing newlines, so a file that ends in one
	# leaves this empty. A file that does not ends with a visible character.
	if [ -n "$(tail -c 1 "$path")" ]; then
		report "$path" 1 "no newline at end of file. Every later append starts on the last line, and diffs say so in red."
	fi

	if [ "$(tr -dc '\r' <"$path" | wc -c)" -ne 0 ]; then
		report "$path" 1 "contains carriage returns. Commit LF endings and let the checkout decide the rest; CRLF in the index breaks shebangs and heredocs on Linux."
	fi

	# Each of these greps its own matches into a variable rather than piping
	# into the loop that reports them: a pipe puts the loop in a subshell, and
	# the failure it recorded there dies with it.
	markers=$(grep -n -e '^<<<<<<<' -e '^|||||||' -e '^>>>>>>>' "$path")
	if [ -n "$markers" ]; then
		while IFS=: read -r lineno text; do
			report "$path" "$lineno" "merge conflict marker left in the file: $text"
		done <<MARKERS
$markers
MARKERS
	fi

	blanks=$(grep -n '[[:blank:]][[:blank:]]*$' "$path")
	if [ -n "$blanks" ]; then
		while IFS=: read -r lineno _; do
			report "$path" "$lineno" "trailing whitespace. It is invisible in the file and loud in the diff, so every later edit to the line shows as a change nobody made."
		done <<BLANKS
$blanks
BLANKS
	fi
done <<EOF
$files
EOF

# Two files whose names differ only in case cannot both exist in a checkout on
# macOS or Windows. The clone appears to succeed and one file arrives holding
# the other's contents.
collisions=$(git ls-files | tr '[:upper:]' '[:lower:]' | sort | uniq -d)
if [ -n "$collisions" ]; then
	while IFS= read -r lowered; do
		clashing=$(git ls-files | grep -ix -- "$lowered" | paste -sd' ' -)
		report "$lowered" 1 "paths differ only in case: $clashing. On a case-insensitive filesystem only one of them can exist."
	done <<EOF
$collisions
EOF
fi

if [ "$status" -eq 0 ]; then
	echo "ok: $(git ls-files | wc -l | tr -d ' ') tracked files, nothing to report"
fi

exit "$status"
