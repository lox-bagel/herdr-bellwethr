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

Nothing here is vendored, and nothing here has a package manifest, so this is
the list. What the code in this repo needs:

- **herdr** — everything here is either a herdr plugin or a caller of its CLI.
  `herdr-plugin.toml` declares `min_herdr_version = "0.7.0"`, which is the floor
  for this plugin alone; the recommended set below asks for more, so 0.7.5 is
  the number to have if you install those too.
- **python3** — `herdr-bellwethr` and `dev-link` are Python, standard library
  only: there is nothing to `pip install`. `tomllib` (3.11+) re-parses the TOML
  `save` generates, because herdr-plus fails its whole projects load on one bad
  file; an older python3 falls back to a regex and loses the check, not the
  command.
- **git** — `hooks/` are git hooks; `dev-link` asks git whether it is in a
  linked worktree before claiming an install's symlinks; `dispatch` and `reap`
  create and remove worktrees and read what has merged.
- **a coding agent** — only for `dispatch`, which asks herdr to start one
  (`--kind claude` by default). herdr launches it, so whichever kind you name is
  the one that has to be installed.

Three things you will have anyway are not dependencies of this code. `gh` is the
pull-request flow the hooks push you toward, not something they call — reviewr
below is what actually wants it installed. `brew` is only how this machine
happens to install herdr, node and fzf. `fzf` belongs to drovr — the delete
picker here draws its own fuzzy list against `termios`, so that it can run in a
pane herdr tears down the moment it exits.

### What the recommended plugins want

`config/plugins.list` is a recommendation, not a requirement. Skip a plugin and
you skip its dependencies with it.

- **herdr-lazy** and **reviewr** (Rust) and **herdr-plus** (Go) each build on
  install, and each avoids needing a toolchain: the first two download a
  release binary and check it (`curl` or `wget`, `tar`, `shasum`/`sha256sum`),
  falling back to `cargo` only when no release matches the platform. herdr-plus
  runs it the other way — `go build` when Go is there, download when it is not.
- **herdr-lazy** reaches for `curl` or `wget` once more after that, in `doctor`,
  which asks GitHub whether each entry in the list still resolves. With neither
  it reports that it could not ask rather than that the repository is gone, so
  this one costs you a check and not a command.
- **reviewr** then needs `bash`, `jq` and `git` at runtime: its `herdr/pane.sh`
  reads every field of its own config and every herdr reply through jq, and
  refuses to open a pane outside a git repository. Its PR tab reads the branch's
  pull request through whichever forge CLI the remote's host calls for —
  `gh`, `glab` or `az` — and that CLI has to be authenticated. Only that one tab
  needs it; without it the tab says so and the rest of reviewr carries on.
- **automatic-rename** needs `bash` and `jq`. Nothing is built or downloaded.
- **drovr** needs **node >= 23** and **fzf**. It ships TypeScript with no build
  step and relies on node's native type stripping to run it, which is where the
  version comes from. fzf draws the picker, and a distribution's fzf can be too
  old for it: 0.44.1 rejects both `--highlight-line` and drovr's `input-fg`
  colour, and the picker exits rather than opening. drovr also wants
  herdr >= 0.7.4 for floating popups.

## Working on it

```sh
git config core.hooksPath hooks   # branch and commit message conventions
./dev-link status                 # what of this checkout a live install is using
./dev-link apply                  # link them, backing up whatever it replaces
```

`dev-link` is for development, not installation: it symlinks so an edit lands in
one place. The installer will copy and record a receipt instead, because a
user's config should not depend on a checkout staying where it was.
