@AGENTS.md

# Claude Code

The working rules are in `AGENTS.md`, imported above. The accumulated facts —
the knowledge this repository already paid for — live in the beads memory store
(`bd memories`, keys prefixed `facts/`), not in a checked-in file: this is a
public repository, and its working notes are not part of the product. Neither
is duplicated here on purpose: this repository has already shipped defects
caused by knowledge copied into a second place and left to rot. One copy, two
harnesses.

The import above is first-level and sits alone on its line. A nested import was
tried here once and silently failed to resolve, so the imported facts were
absent while everything still looked correct. Keep any new import at the top
level, on its own line, with no trailing punctuation.

Everything below is specific to Claude Code and belongs nowhere else.

- Confirm what actually loaded with `/context`, under **Memory files**. If
  `AGENTS.md` is not listed, the import above did not resolve and you are
  working without the rules — say so rather than guessing at them.
- `claude plugin validate <dir> --strict` reads a plugin's skill and command
  frontmatter only when pointed at that plugin's directory. Run it at the repo
  root *and* per plugin.
- Skills in `plugins/*/skills/` are this repo's product. When you change one,
  remember that no schema check reads its prose: the instructions an agent
  follows are testable only by running an agent. See `AGENTS.md` on feedback
  loops, and `plugins/ghostty-config/tests/MANUAL.md` for the worked example.
