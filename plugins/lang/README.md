# lang

Three language rules for coding agents, in one plugin. Each rule is injected as developer context at session start, so it holds on every turn.

| Rule | What it says | Doc |
|---|---|---|
| artifact-language | Talk to the agent in any language. Everything it writes down stays in English: code, comments, Markdown, commit messages, PR bodies and issue text. | [docs/artifact-language.md](docs/artifact-language.md) |
| simpler-english | English prose for a person is easy to read at CEFR B2 level or a little above: short sentences, common words, no idioms, exact technical terms. | [docs/simpler-english.md](docs/simpler-english.md) |
| soft-wrap | Never hard-wrap a paragraph. Prose is one line per paragraph, and the reader's editor wraps it. | [docs/soft-wrap.md](docs/soft-wrap.md) |

The rules are installed together. To turn one off, remove its hook from `hooks/hooks.json` in your copy.

## Install

Claude Code:

```
/plugin marketplace add kmdv181/skills
/plugin install lang@kmdv181-skills
```

Codex:

```
codex plugin marketplace add kmdv181/skills
codex plugin add lang@kmdv181-skills
```

Codex does not run a plugin hook until you approve it, once per machine. Start Codex interactively once after you install the plugin, and approve the hooks. The rule docs show how to check that a rule is loaded.

This plugin replaces `always-english-artifacts`, `always-simpler-english` and `always-soft-wrap`. Uninstall those first, or each rule reaches the agent twice.

## Editing a rule

`rules/<rule>.md` is the source. The hook does not read it. It prints `hooks/<rule>.json`, which `scripts/build.sh` generates from the Markdown. After you edit a rule, run:

```bash
scripts/build.sh     # regenerate every payload; needs jq
scripts/test.sh      # run all checks before you commit
```

Commit the rule and its payload together. `scripts/test.sh` fails if they differ.

## Layout

```
.claude-plugin/plugin.json
hooks/hooks.json             SessionStart -> scripts/emit-rule.sh <rule>, one entry per rule
hooks/<rule>.json            generated payload, committed
rules/<rule>.md              the rule, as prose
docs/<rule>.md               what the rule does and why
scripts/emit-rule.sh <rule>  cat one payload
scripts/build.sh             markdown -> payload, for every rule
scripts/measure.sh           score prose: sentence lengths and banned tokens
scripts/test.sh              hook wiring, then every scripts/test-<rule>.sh
scripts/test-<rule>.sh       payload shape, drift, self-compliance, no-jq execution
tests/probe.sh               plugin enabled vs disabled, scored with measure.sh
```

To add a rule, add `rules/<rule>.md`, a hook entry in `hooks/hooks.json` and `scripts/test-<rule>.sh`. Then run `scripts/build.sh`. `scripts/test.sh` fails if a rule has no hook.
