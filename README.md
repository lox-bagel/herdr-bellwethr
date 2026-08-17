# herdr-bellwethr

A herdr plugin and the herdr configuration around it, kept in one repo because
they ship together.

`herdr-bellwethr` saves the herdr space you are looking at as a herdr-plus
project template, and deletes saved ones from a fuzzy picker — the other half of
herdr-plus's projects browser, which could only open them. Alongside it: the
keybinds, the quick actions the `prefix+a` launcher reads, and the plugin set
herdr-lazy converges to.

```
herdr-bellwethr        the plugin
herdr-plugin.toml      what registers it with herdr
config/                keybinds, quick actions, the herdr-lazy plugin list
config/agent/          the dispatch and reap briefings, one per verb
dev-link               point a live install at this checkout while developing
hooks/                 branch, commit and push conventions
```

Everything here is meant to be installable on any machine. What a particular
machine accumulates is deliberately not:

- **saved projects** — user data, named by whoever ran `herdr-bellwethr save`.
  `config/projects/` holds one as a worked example; it is not installed.
- **`plugins.lock`** — herdr-lazy's record of what it resolved to, rewritten on
  every sync. `config/plugins.list` is the declaration and belongs here; the
  lock is the machine's answer to it and does not.
- **session state, logs, sockets, installed plugin checkouts** — all of it lives
  under `~/.config/herdr` and none of it is ours to carry.

Installing the recommended plugins leaves them installed. Removing this one
takes back only what it put there.

## What has to be on the machine

What a standard Linux or macOS install does not already give you — this repo,
plus every plugin `config/plugins.list` recommends.

| | Used by | Without it |
| --- | --- | --- |
| **herdr** | all of it — this is a herdr plugin and a caller of its CLI | nothing here runs |
| **jq** | reviewr (`herdr/pane.sh`: its config and every herdr reply), automatic-rename (throughout) | reviewr's pane actions refuse; automatic-rename does nothing |
| **gh** / **glab** / **az** | reviewr's PR tab, matched to the remote's host, authenticated; `reap`, which reads pull request state through `gh` | that one tab, which says so; the rest of reviewr is fine. `reap` falls back on what git can see, so a rebase-merged or closed branch looks unfinished |
| **an agent CLI** | `dispatch` (`--kind claude` by default, started by herdr); reviewr's Send targets an agent herdr detected | dispatch cannot hand off; Send has nowhere to send |
| **a Nerd Font** | automatic-rename with `ICONS_ENABLED=1`, off by default | the glyphs |
| **truecolor + Unicode box-drawing** | reviewr's TUI | a readable diff |

The forge CLIs are reviewr's list, not ours: `gh` for GitHub, `glab` for
GitLab, `az` with the `azure-devops` extension for Azure DevOps. Only `gh` has
been used against this repo.

herdr's floor is the highest one any installed plugin declares:

| | |
| --- | --- |
| herdr-bellwethr, herdr-plus | ≥ 0.7.0 |
| automatic-rename | ≥ 0.7.1 |
| herdr-lazy, reviewr | ≥ 0.7.5 |

## Telling an agent about dispatch and reap

`dispatch` and `reap` are things you ask an orchestrating agent for in a
sentence, and they are also ordinary English words. An agent that has to decide
which was meant sometimes decides wrong and answers about scheduling or
harvests instead of running anything. Registering them as its own commands
removes the decision: `/dispatch` is never prose.

```sh
herdr-bellwethr agent-commands                          what is installed, and where
herdr-bellwethr agent-commands install --kind gemini    write the two commands
herdr-bellwethr agent-commands install --kind gemini --stdout   print them instead
herdr-bellwethr agent-commands remove                   take back what it wrote
```

Installing is also in the `prefix+a` launcher, as **Agent: install commands** —
it asks which kind and reports through a notification, since a launcher action
has no terminal to print to. `status` and `remove` stay on the command line,
where their output has somewhere to go.

The briefing for each verb is written once, in `config/agent/`, and knows
nothing about any particular agent. Installing renders it into the shape the
agent reads — markdown with a YAML header, plain markdown, a TOML file, or a
skill directory — and writes a receipt, so `remove` takes back exactly what was
put there and leaves anything since edited alone.

| Kind | Reads from |
| --- | --- |
| `claude` | `~/.claude/commands/*.md` |
| `codex` | `~/.codex/prompts/*.md` |
| `cursor` | `~/.cursor/commands/*.md` |
| `gemini` | `~/.gemini/commands/*.toml` |
| `agy` (Antigravity) | `~/.gemini/antigravity-cli/skills/*/SKILL.md`, or `~/.gemini/config/skills/` on the release that moved it |
| `opencode` | `$XDG_CONFIG_HOME/opencode/commands/*.md` |

The kinds are herdr's own names, the ones `herdr agent start --kind` takes.
herdr knows more of them than this table does; for one of those, say where it
reads commands from and what a file there looks like:

```sh
herdr-bellwethr agent-commands install --kind droid --dir ~/.factory/commands --shape markdown
```

Where an agent lists two directories, whichever exists is used, and if neither
does the install stops and asks — writing to the path a release stopped reading
leaves files nothing will ever open.

## Working on it

```sh
git config core.hooksPath hooks   # branch and commit message conventions
./dev-link status                 # what of this checkout a live install is using
./dev-link apply                  # link them, backing up whatever it replaces
```

`dev-link` is for development, not installation: it symlinks so an edit lands in
one place. The installer will copy and record a receipt instead, because a
user's config should not depend on a checkout staying where it was.
