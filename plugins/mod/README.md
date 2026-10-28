# mod

Claude Code mods by kmdv, in one plugin. A mod changes Claude Code's own interface: a pane, a band, a slash command or a hook on tool calls.

| Mod | What it does |
|---|---|
| mod-beads-tree | Shows the open beads (`bd`) issues as a parent/child tree in a pane. |

## mod-beads-tree

- Opens the pane at session start and refreshes it every 15 seconds. It also refreshes right after a Bash command that runs `bd`.
- `/mod-beads-tree` toggles the pane. It closes the pane when you can see it. Otherwise it refreshes and opens the pane, and says where it was last drawn.
- `/mod-beads-tree open` and `/mod-beads-tree close` do one of the two without toggling.

It needs `bd` on `PATH` and a beads workspace in the project. Without them, the pane shows the error from `bd`.

## Install

```
/plugin marketplace add kmdv181/skills
/plugin install mod@kmdv181
```

Install it at the scope you want: for you on this machine (`user`), for everyone in a project (`project`), or for you in one project (`local`). From a shell:

```bash
claude plugin install mod@kmdv181 --scope project
```

## Develop

Load a working copy for one session:

```bash
claude --plugin-dir plugins/mod
```

Check and test it. The engine writes `.claude-plugin/types/` on first load, and `tsconfig.json` extends it.

```bash
claude plugin validate plugins/mod
claude plugin test plugins/mod
```

## Layout

```
.claude-plugin/plugin.json       manifest, names the state contract
hooks/hooks.json                 names the one hooks module
hooks/register.ts                calls the register of each mod
hooks/mod-beads-tree/            the beads tree mod: register.tsx, tree.ts
types/index.d.ts                 state contract: one key per mod under PluginState["mod"]
tests/mod-beads-tree.test.ts
```

To add a mod, put it in `hooks/<mod-name>/`, export `register` from it, and call it from `hooks/register.ts`. Name its commands, panes and state keys with the mod name, so mods in this plugin do not clash.
