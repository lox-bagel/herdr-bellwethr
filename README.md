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

Nothing here is vendored and nothing here has a package manifest, so this is the
list — this repo, plus every plugin `config/plugins.list` recommends.

### Always

| | Used by | Without it |
| --- | --- | --- |
| **herdr** | all of it — this is a herdr plugin and a caller of its CLI | nothing here runs |
| **git** | `hooks/`; `dev-link` (worktree detection); `dispatch`, `reap` (worktrees, merge state); herdr's own `plugin install`, which shallow-clones; reviewr | no hooks, no dispatch or reap, no plugin installs |
| **python3** | `herdr-bellwethr`, `dev-link` — standard library only, nothing to `pip install` | neither script runs |
| **python3 ≥ 3.11** | `tomllib`, to re-parse the TOML `save` writes — herdr-plus fails its whole projects load on one bad file | the check, not the command: older falls back to a regex |

herdr's floor is the highest one any installed plugin declares:

| | |
| --- | --- |
| herdr-bellwethr, herdr-plus | ≥ 0.7.0 |
| automatic-rename | ≥ 0.7.1 |
| drovr | ≥ 0.7.4 |
| herdr-lazy, reviewr | ≥ 0.7.5 |

### Per plugin

| | Used by | Without it |
| --- | --- | --- |
| **jq** | reviewr (`herdr/pane.sh`: its config and every herdr reply), automatic-rename (throughout) | reviewr's pane actions refuse; automatic-rename does nothing |
| **bash** | reviewr (`herdr/pane.sh`), automatic-rename (3.2 is enough) | same two |
| **curl** | reviewr's installer (no wget path); herdr-lazy and herdr-plus downloads; herdr-lazy `doctor` | reviewr cannot install; the other two build from source instead |
| **wget** | accepted in place of curl by herdr-lazy and herdr-plus only | nothing, if curl is there |
| **node ≥ 23** | drovr, which runs its TypeScript through native type stripping and has no build step | both movers; nothing else |
| **fzf** | drovr's picker | both movers. Also lost if it is too old — 0.44.1 rejects `--highlight-line` and `input-fg`, and the picker exits |
| **gh** / **glab** / **az** | reviewr's PR tab, matched to the remote's host, authenticated | that one tab, which says so; the rest of reviewr is fine |
| **an agent CLI** | `dispatch` (`--kind claude` by default, started by herdr); reviewr's Send targets an agent herdr detected | dispatch cannot hand off; Send has nowhere to send |
| **a Nerd Font** | automatic-rename with `ICONS_ENABLED=1`, off by default | the glyphs |
| **truecolor + Unicode box-drawing** | reviewr's TUI | a readable diff |

### Build toolchains, all avoidable

| | Used by | Without it |
| --- | --- | --- |
| **Go** | herdr-plus prefers it — an exact build of the cloned source | nothing: it downloads a release instead |
| **Rust ≥ 1.78** | herdr-lazy's automatic fallback when no prebuilt matches the platform; reviewr on an unsupported platform or a `plugin link`ed checkout, where you run `cargo install --path .` yourself | nothing on a platform with a prebuilt binary |

### Not dependencies

| | |
| --- | --- |
| **brew** | only how this machine installs herdr, node and fzf |
| **gh**, for this repo | the hooks push you toward the PR flow; nothing here calls it. reviewr is what wants it installed |
| **fzf**, for this repo | the delete picker draws its own list against `termios`, so it can run in a pane herdr tears down on exit |
| **tar**, **sha256sum**/**shasum**, **awk**, **sed**, **mktemp** | used by the installers and drovr's picker; standard on Linux and macOS |

## Working on it

```sh
git config core.hooksPath hooks   # branch and commit message conventions
./dev-link status                 # what of this checkout a live install is using
./dev-link apply                  # link them, backing up whatever it replaces
```

`dev-link` is for development, not installation: it symlinks so an edit lands in
one place. The installer will copy and record a receipt instead, because a
user's config should not depend on a checkout staying where it was.
