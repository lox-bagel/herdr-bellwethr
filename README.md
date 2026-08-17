# herdr-bellwethr

My [herdr](https://herdr.dev) setup: one plugin of my own, plus the config that
goes with it.

The plugin is **herdr-project** — the missing other half of
[herdr-plus](https://github.com/cloudmanic/herdr-plus)'s projects browser.
herdr-plus can *open* a project template; this saves the space you are looking
at back out as one, and deletes saved ones from a fuzzy picker.

Everything else here is configuration: the keybinds in `config.toml`, the
quick-action definitions the herdr-plus launcher reads, and the declarative
plugin set herdr-lazy converges to.

Linux and macOS. herdr's Windows build is preview-beta and nothing here is
written for it.

```
herdr-plugin.toml          the herdr-project plugin manifest (repo root = plugin root)
herdr-project              the plugin itself — save / list / delete projects (python3)
config/
  config.toml              keybinds + theme    -> ~/.config/herdr/config.toml
  plugins.list             desired plugin set  -> herdr-lazy's config dir
  plugins.lock             the commits it resolved to, for a reproducible install
  quick-actions/*.toml     the prefix+a launcher's menu
  projects/*.toml          an example herdr-plus project template
```

## Quick start

Nothing below is interactive and nothing guesses — each step is a command you
can read first.

### 1. herdr itself

```sh
brew install herdr                        # macOS, or Linuxbrew
sh -c "$(curl -fsSL https://herdr.dev/install.sh)"   # anywhere else
```

The curl installer drops the binary in `~/.local/bin` by default
(`HERDR_INSTALL_DIR` overrides it) and verifies the release SHA-256 itself. Put
that directory on your `PATH` if it isn't already. `herdr --version` should
print `0.8.0` or newer — that is what this config is written against.

Run `herdr` once to start the session and let it create `~/.config/herdr`.

### 2. The plugins

```sh
herdr plugin install natori-hrj/herdr-lazy       # declarative plugin manager
herdr plugin install cloudmanic/herdr-plus       # projects + quick-action launcher
herdr plugin install persiyanov/herdr-reviewr    # in-terminal diff review
herdr plugin install qu8n/herdr-automatic-rename # names tabs after what they run
```

herdr-plus is the one the rest of this repo leans on; the other two are here
because I use them, and are safe to skip.

To pin the exact commits this repo was last verified against, install with
`--ref <commit>` from `config/plugins.lock`, or copy `config/plugins.list` and
`config/plugins.lock` into
`~/.config/herdr/plugins/config/herdr-lazy/` and let herdr-lazy do it —
`prefix+shift+l` opens its manage pane, where `s` syncs the machine to the list
and the lock.

Note that herdr-lazy bootstraps itself on the first herdr start after it is
installed: on a machine with no plugins and no list, it writes its own curated
list, installs it, and binds `prefix+shift+l`. Copy the list from this repo
*after* that has happened (or set `HERDR_LAZY_NO_BOOTSTRAP=1` to skip it), or
it will be overwritten.

### 3. The config

`config.toml` here is the whole file, not a fragment — back up yours first if
you have one worth keeping.

```sh
cp ~/.config/herdr/config.toml ~/.config/herdr/config.toml.bak   # if it exists
cp config/config.toml ~/.config/herdr/config.toml

mkdir -p ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions
cp config/quick-actions/*.toml \
   ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/

herdr server reload-config
```

The keybinds in `config.toml` invoke plugin actions, so install the plugins
first — a binding whose plugin is missing does nothing.

### 4. The herdr-project plugin

```sh
git clone https://github.com/lox-bagel/herdr-bellwethr ~/ws/herdr-bellwethr
herdr plugin link ~/ws/herdr-bellwethr
```

The repo root *is* the plugin root, so link the checkout itself. Needs `python3`
on `PATH` (3.11+ parses the TOML it reads with `tomllib`; older versions fall
back to a regex and work fine). Put `herdr-project` on your `PATH` too — the
`prefix+shift+s` keybind runs it as a bare command:

```sh
ln -s ~/ws/herdr-bellwethr/herdr-project ~/.local/bin/herdr-project
```

### 5. Check it

`prefix+a` should open the quick-action launcher with the list below in it.
`prefix+shift+s` saves the current space as a project, `prefix+shift+o` opens
the browser you can rebuild it from.

## Keybinds

Set in `config.toml`. Everything else is herdr's own default binding, left
alone.

| key | does |
|---|---|
| `prefix+a` | Quick actions — the herdr-plus launcher |
| `prefix+shift+o` | Herdr Plus: projects browser (open a template) |
| `prefix+shift+s` | Herdr Plus: save this space over the project named after it |
| `prefix+shift+l` | herdr-lazy: manage plugins |

`prefix+?` lists them, which is why every binding in `config.toml` carries a
`description` — one without it shows up nameless.

## Quick actions

`prefix+a` opens a fuzzy list of these. Most of them wrap a herdr command that
already has a key; the launcher is the discoverable version, which is the point
— the description of each one names the key it duplicates, so the list doubles
as a cheatsheet you can act on.

| action | what it runs |
|---|---|
| `Herdr: new tab` / `new workspace` | `herdr tab create` / `herdr workspace create` |
| `Herdr: split horizontal` / `vertical` | `herdr pane split --direction down` / `right` |
| `Herdr: focus pane up/down/left/right` | `herdr pane focus --direction …` |
| `Herdr: focus agent` | `herdr agent focus` |
| `Herdr: switch tab` / `switch workspace` | `herdr tab focus` / `herdr workspace focus` |
| `Herdr: rename pane` / `tab` / `workspace` | `herdr … rename` |
| `Herdr: close pane` / `tab` / `workspace` | `herdr … close`, behind a yes/no select |
| `Herdr: new worktree` / `open` / `remove` | `herdr worktree create` / `open` / `remove` |
| `Herdr: reload config` | `herdr server reload-config` |
| `Lazy: manage plugins` / `sync plugins` | herdr-lazy's manage pane / `sync` |
| `Plus: projects` | the herdr-plus projects browser |
| `Plus: save project` | `herdr-project save --force` — overwrite the project named after this space |
| `Plus: save as project` | `herdr-project save <name>` — prompts for a new name |
| `Plus: delete project` | the fuzzy delete picker from this repo's plugin |

The names are padded with trailing spaces on purpose: the launcher lays the
name and description out in one column each, and equal-width names keep the
descriptions aligned.

## herdr-project

```sh
herdr-project save                    # save the current space, named after it
herdr-project save "Options Cafe"     # …under a different name
herdr-project save --stdout           # print the TOML instead of writing it
herdr-project list                    # what is in the projects dir
herdr-project delete                  # fuzzy-pick one to delete
herdr-project delete "Options Cafe"   # or name it
```

`save` snapshots the space you are looking at — tabs, panes, split directions,
working dirs, and the commands actually running — into one `*.toml` in
herdr-plus's `projects/` dir, so `prefix+shift+o` can rebuild it later.

It reads live state over herdr's socket API (`herdr workspace|tab|pane …`),
never `~/.config/herdr/session.json`, which is a persistence detail and lags the
running session. A few things it takes care of:

- **The plugin panes disappear.** The launcher or picker you invoked it from is
  a pane of the space like any other while it is open; saving from one would
  otherwise write the launcher into the template.
- **So does the saver itself.** Anything in this script's own process tree is
  skipped — except in an agent pane, where `claude` genuinely is what that pane
  runs, even when it is the caller.
- **Layout comes from pane geometry**, not from herdr's generated split ids, and
  is flattened into the linear pane chain herdr-plus rebuilds from. Anything
  that cannot be reproduced exactly (nested splits, non-even ratios, a fifth
  pane in a tab) is warned about rather than silently changed.
- **Paths stay portable.** `~` survives into the file, and panes outside the
  project's `working_dir` get a `cd` in front of their command, since a
  herdr-plus project has one working dir and no per-pane cwd.
- **Generated TOML is parsed before it is written.** herdr-plus fails its whole
  projects load on one malformed file, which would take your other projects down
  with it.

Only the delete picker needs to be a plugin: it needs a terminal to draw a fuzzy
list in, and herdr only hands a pane to a registered plugin. Saving is a
one-shot command a keybind can run directly — which is why `prefix+shift+s` is a
`shell` binding, not a `pane` one. A `pane` binding would add a pane to the very
space being saved.

## Keeping this repo current

The config here is a copy of what is live, so it drifts. To pull the machine's
state back in:

```sh
cp ~/.config/herdr/config.toml config/config.toml
cp ~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions/*.toml config/quick-actions/
cp ~/.config/herdr/plugins/config/herdr-lazy/plugins.list config/plugins.list
cp ~/.config/herdr/plugins/config/herdr-lazy/plugins.lock config/plugins.lock
```

Saved projects are per-machine snapshots — full of local paths and whatever was
running at the time — so they are not synced wholesale. `config/projects/` holds
one as a worked example of the format.
