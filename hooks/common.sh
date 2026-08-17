# common.sh — the conventions every hook in this directory checks against.
#
# Sourced, never run. It exists so the type list and the branch pattern have one
# definition: pre-commit, pre-push and commit-msg all enforce some part of the
# same convention, and three copies of a regex drift the first time somebody
# adds a type to one of them.
#
# The GitHub workflow that lints pull request titles cannot source this file —
# it runs on a checkout of the PR, before any of this is on PATH, and a shell
# variable is not visible to YAML anyway. It repeats the pattern with a comment
# pointing here. Change one, change the other.

# Conventional Commits types, as an alternation ready to drop into a regex.
#
# Deliberately short. A type list nobody can recall is a list people work around
# with `chore:`, and then the prefix carries no information at all.
#
#   feat      a capability the user did not have before
#   fix       behaviour that was wrong and now is not
#   docs      documentation and comments only
#   refactor  same behaviour, different shape
#   chore     housekeeping — renames, config, dependency bumps
#   test      tests only
#   build     how the thing is built or packaged
#   ci        the automation around it
BELLWETHR_TYPES='feat|fix|docs|refactor|chore|test|build|ci'

# Branch names: <type>/<kebab-slug>, same vocabulary as the commit prefix.
#
# main is not matched here and does not need to be — pre-commit and pre-push
# refuse it by name, with a message about pull requests rather than about
# spelling, which is the more useful thing to say.
BELLWETHR_BRANCH_RE="^(${BELLWETHR_TYPES})/[a-z0-9]+(-[a-z0-9]+)*\$"

# True for the branches git and its tooling create on their own. Refusing these
# would break rebases, bisects and `gh pr checkout`, none of which are somebody
# choosing a name badly.
bellwethr_branch_is_exempt() {
	case "$1" in
	main | HEAD | "") return 0 ;;
	revert-*) return 0 ;;         # the button GitHub puts on a merged PR
	dependabot/*) return 0 ;;     # named by a bot, to a scheme that is not ours
	esac
	return 1
}

# Complain about a branch name, or say nothing and return 0.
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
	echo "  BELLWETHR_ALLOW_MAIN=1 ...        skip every check in these hooks" >&2
	return 1
}
