# Changelog

What this marketplace has shipped, newest first. Versions refer to the plugin manifests; dates come from git history, and the commit messages carry the full reasoning and evidence behind every line here.

## Unreleased

- `always-soft-wrap` 0.1.0 — new plugin: a session-wide rule against hard line breaks, injected at session start — a paragraph, and any sentence inside one, is a single line in the file, soft-wrapped by the reader's editor; code blocks and structure are untouched. Born from PR #1 review, which caught the same wrapped paragraphs three times by hand.
- `nightcap` 0.1.0 — new plugin: a memory checkpoint an agent calls on itself, distilling the session into persistent beads memory and sealing one key with the state of play, the next move, and the agent's last proposal verbatim.
- `always-english-artifacts` 0.2.1 — the artifact-language rule now states that quoted evidence is not exempt: non-English command output or probe results landing in a commit message, PR body, or memory entry must be translated or stated as a finding.

## 2026-08-27

- `always-english-artifacts` 0.2.0 — one exception added to the rule: replies in GitHub discussions follow the language of the comment they answer; everything else on GitHub stays English.

## 2026-08-09

- `ghostty-config` 0.1.11 — the installed-copy drift check compared against the wrong installed version; fixed.
- `ghostty-config` 0.1.10 — `tests/MANUAL.md` no longer carries its own copy of the version number.
- `ghostty-config` 0.1.9 — `GHOSTTY_BACKUP_KEEP` had two ways to destroy the backup ring (octal arithmetic on leading zeros, a numeric guard that missed `00`); both fixed, backup pruning now sorts under `LC_ALL=C`.
- Marketplace — `ghostty-config` verified end to end under Codex; the README's harness table now records measured runs, not expectations.

## 2026-08-08

- `ghostty-config` 0.1.8 — third test tier added: the real binary drives the plugin's scripts end to end against a fixture.
- `ghostty-config` 0.1.7 — a key absent from `+show-config --default` is no longer reported as a typo (deprecated aliases still validate); manual test procedure added.
- `ghostty-config` 0.1.6 — stopped marking every valid key a typo on Ghostty builds without `+explain-config`.
- `ghostty-config` 0.1.5 — clearing the config is no longer a dead end.
- `ghostty-config` 0.1.4 — skills renamed to `edit` and `undo`. Shipped with four defects rooted in knowledge baked into prose and gone stale against the installed Ghostty; testing against the real binary found them, and 0.1.5–0.1.7 fixed them.
- `ghostty-config` 0.1.3 — backups capped at five; undo asks which backup to restore.
- `ghostty-config` 0.1.2 — undo became a skill and `commands/` was removed: commands and skills share one namespace, and the shadowed command was dead weight.
- `ghostty-config` 0.1.1 — first tagged release; the shipping steps (version bump in both manifests, tag, marketplace refresh) written down after learning them the hard way.
- Marketplace — renamed from `181-lab` to `kmdv181`; the empty `kmdv` plugin dropped; install instructions pointed at `kmdv181/skills`.
- Marketplace — set up with its first two plugins: `always-english-artifacts` 0.1.0 and `ghostty-config`.
