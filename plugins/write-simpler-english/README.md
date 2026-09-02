# write-simpler-english

Every piece of English prose the agent writes for a person is easy to read at CEFR B2 level or a little above.

```
/plugin marketplace add kmdv181/skills
/plugin install write-simpler-english@kmdv181
```

## What it does

At session start the plugin injects one rule as developer context. **Write English that a non-native reader at B2 level, or a little above, can read once and understand.** The rule gives numbers, not adjectives. Sentences aim for about 18 words and never pass 30. Each sentence carries one idea, in the active voice, with a named subject. The rule prefers the common word over the C1 word when both mean the same thing. It bans idioms, irony, double negatives, Latin abbreviations, em dashes and semicolons.

It covers everything the agent writes in English for a person: chat replies, Markdown, commit messages, PR bodies, code comments and issue text. Text that only an agent will read is exempt, such as memory entries and prompts for subagents.

It sets the reading level, not the language. A conversation in Russian still gets replies in Russian. Which artifacts must be in English is the job of `always-english-artifacts`, and the two plugins compose.

Two things stay exact whatever the level. Technical terms are never replaced with a vaguer word, so "mutex" stays "mutex". Code, identifiers, commands, quoted errors and the user's own words are never simplified. When precision and simplicity conflict, precision wins.

The rule also pins two edits that otherwise go wrong. An edit to a dense paragraph applies the rule to the sentences the agent touches and leaves the rest alone, so nothing gets rewritten uninvited. A request from you for a particular style, tone or level wins over the rule.

## Why a hook and not a skill

Skills load on demand. This rule has to hold on every turn. It matters most on turns where nothing signals that readability is relevant, because that is when the 40-word sentence gets written. So it ships as a `SessionStart` hook that injects the rule as context. Plugins cannot contribute `CLAUDE.md` content, and a hook is the only always-on mechanism available to one.

The matcher covers `startup|resume|clear|compact|fork`, so the rule is injected again after a compaction rather than quietly disappearing mid-session.

## Why these numbers

Sentence length separates A-level readers from B-level readers, but it barely separates B2 from C1. The CEFR-SP corpus holds 17,000 English sentences graded by English-teaching professionals (Arase, Uchida and Kajiwara, 2022). Its mean sentence length is 15.2 words at B1, 18.0 at B2 and 19.0 at C1. What rises with level is vocabulary. So the rule sets the target at 18 words with a hard cap of 30, and it swaps only C1 and C2 words for common ones. The cap is a maximum for one sentence, not a target for the mean.

## Codex

The mechanism is the one `always-english-artifacts` runs under Codex unmodified: discovery through this repo's `.claude-plugin/marketplace.json`, the same `hooks/hooks.json` path, the same `hookSpecificOutput.additionalContext` payload. This plugin itself has not been run under Codex yet. The marketplace README's harness table records runs, not expectations.

If you try it there, remember that installing does not trust the hook. Codex skips plugin-bundled hooks, silently, until you approve the hook definition once per machine. Start Codex interactively once after installing.

## Editing the rule

`rules/simpler-english.md` is the source. The hook does not read it directly. It prints `hooks/session-start.json`, generated from the Markdown:

```bash
scripts/build.sh     # regenerate the payload; needs jq
scripts/test.sh      # verify; run before committing
```

Commit both files. `scripts/test.sh` fails if they have drifted. It also fails if the rule text, or this README, breaks the rule's own limits. The limits it checks are no sentence over 30 words, a mean under 20, and no em dash, semicolon or Latin abbreviation. The rule cannot ship in violation of itself.

The payload is pre-encoded rather than built at session start so the hook has no runtime dependency beyond `cat`. A hook that needs `jq` fails silently on a machine without it, and a silently missing rule is worse than no plugin.

## Verifying

`scripts/measure.sh` is the scorer. It reads English prose on stdin and prints sentence count, mean and maximum words per sentence, and counts of em dashes, semicolons and Latin abbreviations. `scripts/test.sh` calibrates it against two hardcoded fixtures before trusting it, then scores the rule and this README.

Schema checks say nothing about whether a rule changes what a model writes. `tests/probe.sh` measures that. It runs a fixed set of prompts through `claude -p` with the plugin enabled and then disabled, scores every reply with `measure.sh`, and prints a verdict. It spends tokens, so it refuses to run unless `PROBE_BUDGET_TOKENS` is set, and it stops once the total reaches that cap:

```bash
PROBE_BUDGET_TOKENS=400000 tests/probe.sh
```

It needs the plugin installed from a scratch copy of this marketplace named `kmdv181-local`, and it skips loudly without it. Results stay in `PROBE_OUT`. A rerun with the same directory and a wider `PROBE_SET` reuses finished runs and spends tokens only on the new prompts.

Measured on 2026-09-02 against `claude-fable-5-1` through `claude -p`, 24 runs, 172k tokens. The disabled baseline already wrote no em dashes or semicolons and averaged 11 to 13 words per sentence, so the rule's measurable effect is on the tail. On the two prompts where the baseline broke the cap, disabled runs had sentences of 31 to 35 words. Enabled runs peaked at 19 to 29 words, with means about a fifth lower. Two prompts were uninformative because the baseline already obeyed the rule. The over-reach checks passed: Russian stayed Russian, and a commit message and a code sample did not grow. The exemption for agent-only text is not measured by the probe. A memory entry from the model is short with or without the rule, so the two arms would not differ. And no difference is also what a broken exemption would produce.

## Layout

```
.claude-plugin/plugin.json
hooks/hooks.json            SessionStart -> scripts/emit-rule.sh
hooks/session-start.json    generated payload, committed
rules/simpler-english.md    the rule, as prose
scripts/emit-rule.sh        cat the payload
scripts/build.sh            markdown -> payload
scripts/measure.sh          score prose: sentence lengths and banned tokens
scripts/test.sh             payload shape, drift, scorer calibration, self-compliance
tests/probe.sh              enabled vs disabled, scored with measure.sh
```
