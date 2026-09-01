# always-soft-wrap

One line per paragraph: the file never hard-wraps prose; your editor soft-wraps it.

```
/plugin marketplace add kmdv181/skills
/plugin install always-soft-wrap@kmdv181
```

## What it does

At session start the plugin injects one rule as developer context: **never hard-wrap a paragraph.** A paragraph — and any sentence inside one — is a single line in the file; rendering long lines is the reader's editor's job. That covers Markdown and plain-text prose, list items and their would-be continuations, and prose that travels through tools rather than files, such as issue descriptions and memory entries.

It leaves alone the things that have their own formatting: code and fenced blocks, comments inside source code, heading and table structure, YAML frontmatter, and commit message bodies, which keep git's conventional ~72-column wrapping because they are read by tools that do not soft wrap.

The rule also pins the two edits that otherwise go wrong:

- An edit to an already hard-wrapped paragraph re-flows that paragraph to a single line, so files converge instead of mixing both styles forever.
- Nothing else gets re-flowed uninvited. A sweep through untouched files tramples other people's diffs in a shared repository; re-flow follows the edit rather than going looking for work.

## Why a hook and not a skill

Skills load on demand. This rule has to hold on every turn — most of all on turns where nothing signals that formatting is relevant, because that is when the wrapped paragraph gets written. So it ships as a `SessionStart` hook that injects the rule as context. Plugins cannot contribute `CLAUDE.md` content; a hook is the only always-on mechanism available to one.

The matcher covers `startup|resume|clear|compact|fork`, so the rule is re-injected after a compaction rather than quietly disappearing mid-session.

## Codex

The mechanism is the one `always-english-artifacts` runs under Codex unmodified: discovery through this repo's `.claude-plugin/marketplace.json`, the same `hooks/hooks.json` path, the same `hookSpecificOutput.additionalContext` payload. This plugin itself has not been run under Codex yet — the marketplace README's harness table records runs, not expectations.

If you try it there, remember that installing does not trust the hook: Codex skips plugin-bundled hooks, silently, until you approve the hook definition once per machine. Start Codex interactively once after installing.

## Editing the rule

`rules/soft-wrap.md` is the source. The hook does not read it directly — it prints `hooks/session-start.json`, generated from the Markdown:

```bash
scripts/build.sh     # regenerate the payload; needs jq
scripts/test.sh      # verify; run before committing
```

Commit both files. `scripts/test.sh` fails if they have drifted — and it also fails if the rule text itself contains a hard-wrapped paragraph, so the rule cannot ship in violation of itself.

The payload is pre-encoded rather than built at session start so the hook has no runtime dependency beyond `cat`. A hook that needs `jq` fails silently on a machine without it, and a silently missing rule is worse than no plugin.

## Layout

```
.claude-plugin/plugin.json
hooks/hooks.json            SessionStart -> scripts/emit-rule.sh
hooks/session-start.json    generated payload, committed
rules/soft-wrap.md          the rule, as prose
scripts/emit-rule.sh        cat the payload
scripts/build.sh            markdown -> payload
scripts/test.sh             payload shape, drift, self-compliance, no-jq execution
```
