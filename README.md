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

## Working on it

```sh
git config core.hooksPath hooks   # branch and commit message conventions
./dev-link status                 # what of this checkout a live install is using
./dev-link apply                  # link them, backing up whatever it replaces
```

`dev-link` is for development, not installation: it symlinks so an edit lands in
one place. The installer will copy and record a receipt instead, because a
user's config should not depend on a checkout staying where it was.
