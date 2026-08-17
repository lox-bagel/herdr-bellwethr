#!/bin/sh
#
# lint.sh — parse and lint every language this repository actually contains:
# POSIX shell, Python 3, TOML, JSON and YAML. A file that does not parse is a
# file whose review said nothing about what it does, and the parsers cost
# milliseconds.
#
#   .github/checks/lint.sh
#
# Every tool it reaches for is already on the GitHub-hosted Ubuntu runners:
#
#   - the shell linter, which they preinstall.
#   - python3, where everything asked of it — compile(), tabnanny, tomllib,
#     json — is standard library, so this installs nothing and pulls nothing
#     from a registry.
#   - a YAML reader, the one format the standard library has none of: PyYAML if
#     the interpreter has it, Ruby's Psych otherwise. Both ship on the image.
#
# A missing tool fails the check rather than being skipped quietly, because a
# lint that silently stands down is worse than no lint at all. Locally, where
# the tools may genuinely not be installed, BELLWETHR_ALLOW_MISSING_TOOLS=1
# turns each absence into a printed notice instead.
#
# What it deliberately does not do:
#
#   - no formatter and no style rules: no ruff, black, prettier or yamllint.
#     Those are opinions, and they arrive through pip or npm, which is a third
#     party's code running in CI — the same trade this repository refuses for
#     marketplace actions. Refusing it there and taking it here would be
#     nonsense.
#   - it does not run this project's own tests or start it. This file knows
#     syntax, not behaviour.
#
# File lists reach the helpers through the environment, one path per line,
# never as an interpolated argument string. Same reason as the workflow: a
# path is data, and data pasted into a program's source is a program somebody
# else gets to write.

status=0

# The linter cannot follow `. "$(dirname "$0")/common.sh"` — it would have to
# run the script to know what that path is — and says so on every hook. The
# finding is true and useless.
shellcheck_excludes='SC1091'

report() {
	if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
		printf '::error file=%s,line=%s::%s\n' "$1" "$2" "$3"
	else
		printf '%s:%s: %s\n' "$1" "$2" "$3"
	fi
	status=1
}

# Turn `path:line:col: level: message` — the gcc format shellcheck speaks, and
# the helpers below are written to speak — into one annotation per finding.
# Fed from a here-document, never a pipe: a pipe would run this in a subshell
# and take every failure it recorded down with it.
annotate() {
	while IFS= read -r finding; do
		[ -n "$finding" ] || continue
		file=${finding%%:*}
		rest=${finding#*:}
		line=${rest%%:*}
		message=${rest#*:}
		# Drop the column: an annotation is placed by line, and the number
		# reads as part of the message when it is left in.
		case ${message%%:*} in
		'' | *[!0-9]*) ;;
		*) message=${message#*:} ;;
		esac
		case $line in
		'' | *[!0-9]*) report "$file" 1 "$finding" ;;
		*) report "$file" "$line" "${message# }" ;;
		esac
	done
}

first_line_of() {
	IFS= read -r first <"$1" 2>/dev/null || first=''
	printf '%s' "$first"
}

# Sort the tracked files by language. A repository that names its programs
# after what they do rather than what they are written in — this one has
# `herdr-bellwethr` and `dev-link`, both Python, neither ending .py — cannot be
# sorted by extension alone, so the shebang decides the rest.
shell_files=''
python_files=''
toml_files=''
json_files=''
yaml_files=''

add() {
	# $1 is the name of a list variable, $2 the path to append to it.
	eval "$1=\"\${$1}\$2
\""
}

while IFS= read -r path; do
	[ -f "$path" ] || continue

	case $path in
	*.sh) add shell_files "$path" ;;
	*.py) add python_files "$path" ;;
	*.toml) add toml_files "$path" ;;
	*.json) add json_files "$path" ;;
	*.yml | *.yaml) add yaml_files "$path" ;;
	*)
		case $(first_line_of "$path") in
		'#!'*python*) add python_files "$path" ;;
		'#!'*sh | '#!'*sh\ *) add shell_files "$path" ;;
		esac
		;;
	esac
done <<EOF
$(git ls-files)
EOF

if [ -n "$shell_files" ]; then
	if ! command -v shellcheck >/dev/null 2>&1; then
		if [ -n "${BELLWETHR_ALLOW_MISSING_TOOLS:-}" ]; then
			echo "notice: no shell linter installed, skipped by BELLWETHR_ALLOW_MISSING_TOOLS"
		else
			report ".github/checks/lint.sh" 1 "no shell linter installed. It ships on the GitHub runners; locally, install it, or set BELLWETHR_ALLOW_MISSING_TOOLS=1 and accept that the shell went unchecked."
		fi
	else
		while IFS= read -r path; do
			[ -n "$path" ] || continue

			# A sourced fragment has no shebang to declare its dialect, so
			# name the dialect of the scripts that source it: POSIX sh.
			case $(first_line_of "$path") in
			'#!'*) findings=$(shellcheck -f gcc -e "$shellcheck_excludes" "$path") ;;
			*) findings=$(shellcheck -f gcc -s sh -e "$shellcheck_excludes" "$path") ;;
			esac

			annotate <<FINDINGS
$findings
FINDINGS
		done <<EOF
$shell_files
EOF
		printf 'shellcheck: %s\n' "$(printf '%s' "$shell_files" | tr '\n' ' ')"
	fi
fi

if [ -n "$python_files" ]; then
	# compile() is the parser the interpreter itself uses, so it accepts
	# exactly what running the file would. tabnanny catches indentation that
	# reads one way and runs another: a tab and eight spaces look identical and
	# are not the same to Python.
	findings=$(BELLWETHR_FILES="$python_files" python3 <<'PY'
import os
import sys
import tabnanny
import tokenize

status = 0

for path in os.environ["BELLWETHR_FILES"].splitlines():
    if not path:
        continue

    with open(path, "rb") as handle:
        source = handle.read()

    try:
        compile(source, path, "exec")
    except (SyntaxError, ValueError) as error:
        line = getattr(error, "lineno", None) or 1
        column = getattr(error, "offset", None) or 1
        message = getattr(error, "msg", None) or str(error)
        print(f"{path}:{line}:{column}: error: {message}")
        status = 1
        continue

    try:
        with open(path, encoding="utf-8") as handle:
            tabnanny.process_tokens(tokenize.generate_tokens(handle.readline))
    except tabnanny.NannyNag as nag:
        print(f"{path}:{nag.get_lineno()}:1: error: ambiguous indentation: {nag.get_msg().strip()}")
        status = 1

sys.exit(status)
PY
	)
	annotate <<FINDINGS
$findings
FINDINGS
	printf 'python: %s\n' "$(printf '%s' "$python_files" | tr '\n' ' ')"
fi

if [ -n "$toml_files" ]; then
	findings=$(BELLWETHR_FILES="$toml_files" python3 <<'PY'
import os
import sys
import tomllib

status = 0

for path in os.environ["BELLWETHR_FILES"].splitlines():
    if not path:
        continue

    try:
        with open(path, "rb") as handle:
            tomllib.load(handle)
    except tomllib.TOMLDecodeError as error:
        print(f"{path}:1:1: error: {error}")
        status = 1

sys.exit(status)
PY
	)
	annotate <<FINDINGS
$findings
FINDINGS
	printf 'toml: %s\n' "$(printf '%s' "$toml_files" | tr '\n' ' ')"
fi

if [ -n "$json_files" ]; then
	findings=$(BELLWETHR_FILES="$json_files" python3 <<'PY'
import json
import os
import sys

status = 0

for path in os.environ["BELLWETHR_FILES"].splitlines():
    if not path:
        continue

    try:
        with open(path, "rb") as handle:
            json.load(handle)
    except json.JSONDecodeError as error:
        print(f"{path}:{error.lineno}:{error.colno}: error: {error.msg}")
        status = 1

sys.exit(status)
PY
	)
	annotate <<FINDINGS
$findings
FINDINGS
	printf 'json: %s\n' "$(printf '%s' "$json_files" | tr '\n' ' ')"
fi

if [ -n "$yaml_files" ]; then
	if python3 -c 'import yaml' >/dev/null 2>&1; then
		echo "yaml parser: PyYAML"
		findings=$(BELLWETHR_FILES="$yaml_files" python3 <<'PY'
import os
import sys

import yaml

status = 0

for path in os.environ["BELLWETHR_FILES"].splitlines():
    if not path:
        continue

    try:
        with open(path, "rb") as handle:
            # compose_all, not load_all: this asks whether the document is well
            # formed and refuses to construct whatever tag it asks for.
            list(yaml.compose_all(handle))
    except yaml.YAMLError as error:
        mark = getattr(error, "problem_mark", None)
        line = mark.line + 1 if mark else 1
        problem = getattr(error, "problem", None) or str(error)
        print(f"{path}:{line}:1: error: {problem}")
        status = 1

sys.exit(status)
PY
		)
		annotate <<FINDINGS
$findings
FINDINGS
	elif command -v ruby >/dev/null 2>&1; then
		echo "yaml parser: Ruby Psych"
		findings=$(BELLWETHR_FILES="$yaml_files" ruby -ryaml -e '
status = 0
ENV["BELLWETHR_FILES"].split("\n").reject(&:empty?).each do |path|
  begin
    Psych.parse_stream(File.read(path), filename: path)
  rescue Psych::SyntaxError => error
    puts "#{path}:#{error.line}:#{error.column}: error: #{error.problem}"
    status = 1
  end
end
exit status
')
		annotate <<FINDINGS
$findings
FINDINGS
	elif [ -n "${BELLWETHR_ALLOW_MISSING_TOOLS:-}" ]; then
		echo "notice: no YAML parser installed, skipped by BELLWETHR_ALLOW_MISSING_TOOLS"
	else
		report ".github/checks/lint.sh" 1 "no YAML parser available: neither PyYAML nor Ruby is installed, and the standard library has no reader for it. The YAML in this repository went unchecked."
	fi
	printf 'yaml: %s\n' "$(printf '%s' "$yaml_files" | tr '\n' ' ')"
fi

if [ "$status" -eq 0 ]; then
	echo "ok: everything parses, shellcheck is clean"
fi

exit "$status"
