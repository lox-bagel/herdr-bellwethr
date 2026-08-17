---
description: Hand a task to an agent working in a fresh git worktree.
argument-hint: the task, in the words you would use to explain it
---

Hand the task below to a new agent by running `herdr-bellwethr dispatch`. This
is a command to run, not work to do yourself: dispatch creates a worktree,
starts an agent in it, writes the task down and hands it over.

The task, as it was given to you:

{{args}}

Then:

1. If nothing was given, ask what to dispatch. Do not invent a task.
2. Run `herdr-bellwethr conventions` in the repository. It reports the recent
   branch names, the recent commit subjects, and the hooks that will actually
   run — which is what a branch name has to satisfy.
3. Pick a branch name that fits that evidence, and run:

       herdr-bellwethr dispatch "<the task, exactly as it was given>" --branch <name>

   Pass the task through unchanged. Do not summarise it, do not add file or
   line numbers that were not given, and do not settle anything it left open.
   dispatch tells the agent it is allowed to ask, and a task that was tidied
   up on the way has nothing left to ask about.
4. Report what dispatch printed: the branch, the agent alias, the checkout and
   the workspace.

`--base <ref>` starts the branch somewhere other than main, and `--kind <agent>`
starts an agent other than the default one. dispatch decides the rest for
itself; `--help` lists what is left.
