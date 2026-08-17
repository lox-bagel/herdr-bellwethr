# common.sh — conventions shared by pre-commit, pre-push and commit-msg.
#
# .github/workflows/pr-title.yml repeats this pattern: a workflow cannot source
# a shell file that is not on the runner's path yet. Change one, change the other.

BELLWETHR_TYPES='feat|fix|docs|refactor|chore|test|build|ci'

BELLWETHR_BRANCH_RE="^(${BELLWETHR_TYPES})/[a-z0-9]+(-[a-z0-9]+)*\$"

# Branches git and its tooling create on their own. Refusing these would break
# rebases, bisects and `gh pr checkout`.
bellwethr_branch_is_exempt() {
	case "$1" in
	main | HEAD | "") return 0 ;;
	revert-*) return 0 ;;         # the button GitHub puts on a merged PR
	dependabot/*) return 0 ;;     # named by a bot, to a scheme that is not ours
	esac
	return 1
}

bellwethr_check_branch() {
	branch="$1"
	hook="$2"

	if bellwethr_branch_is_exempt "$branch"; then
		return 0
	fi

	if printf '%s' "$branch" | grep -Eq "$BELLWETHR_BRANCH_RE"; then
		return 0
	fi

	echo "$hook: branch name '$branch' is not <type>/<kebab-slug>." >&2
	echo >&2
	echo "  types:   $(printf '%s' "$BELLWETHR_TYPES" | tr '|' ' ')" >&2
	echo "  example: feat/pr-title-lint" >&2
	echo >&2
	echo "  git branch -m <new-name>          rename it" >&2
	echo "  BELLWETHR_SKIP_CHECKS=1 ...       skip every check in these hooks" >&2
	return 1
}
