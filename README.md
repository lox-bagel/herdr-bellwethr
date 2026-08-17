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
| **node ≥ 23** | drovr, which runs its TypeScript through native type stripping and has no build step | both movers; nothing else |
| **fzf** | drovr's picker | both movers. Also lost if it is too old — 0.44.1 rejects `--highlight-line` and `input-fg`, and the picker exits |
| **gh** / **glab** / **az** | reviewr's PR tab, matched to the remote's host, authenticated | that one tab, which says so; the rest of reviewr is fine |
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
| drovr | ≥ 0.7.4 |
| herdr-lazy, reviewr | ≥ 0.7.5 |

## Working on it

```sh
git config core.hooksPath hooks   # branch and commit message conventions
./dev-link status                 # what of this checkout a live install is using
./dev-link apply                  # link them, backing up whatever it replaces
```

`dev-link` is for development, not installation: it symlinks so an edit lands in
one place. The installer will copy and record a receipt instead, because a
user's config should not depend on a checkout staying where it was.
