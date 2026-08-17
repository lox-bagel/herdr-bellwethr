---
description: Report which dispatched worktrees look finished with.
argument-hint: anything to pass through, such as --base develop
---

Run `herdr-bellwethr reap` in the repository and report what it says. This is a
command to run, not work to do yourself.

Anything given after the command name, to be passed through as it stands:

{{args}}

`reap` lists the worktrees dispatch created and says, for each, whether its work
has landed. It reads pull request state through `gh`, and falls back on what git
alone can see when `gh` cannot answer. On its own it only reports.

Removing a worktree needs `--remove`, and the branch goes too only with
`--remove --delete-branch`. Both destroy work that may exist nowhere else, and a
branch outlives its pull request on purpose — it is what the work is still
called afterwards. Pass either flag only when it was asked for in as many words,
and then say which worktrees went.
