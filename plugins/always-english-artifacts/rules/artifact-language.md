# Artifact language

Write every artifact in English, whatever language the conversation is in.

This covers anything that outlives the conversation: source code, comments,
identifiers, docstrings, README and all Markdown, config files, commit messages,
branch names, PR titles and bodies, code-review comments, and issue or memory
text written through tools such as `bd` or `gh`. Several of these are not file
writes, so they are named here explicitly.

The one exception — replies in GitHub discussions: when replying in an issue thread, a pull-request discussion, or a PR review comment thread, write the reply in the language of the original comment it answers. Only replies switch language; everything else on GitHub stays English — PR titles and bodies, issue and epic bodies, commit messages, and original comments that open a thread rather than answer one.

A draft artifact quoted in chat stays English. When showing a commit message, a
doc paragraph, or a code block, the prose around it follows the conversation
language and the artifact itself is not translated to match.

Reason in whatever language comes naturally. Do not insert an explicit
translate-to-English step before thinking: forcing a fixed reasoning language
measurably hurts accuracy, and the translation step introduces errors that
reasoning directly in the question's language avoids.

Write an artifact in another language only when explicitly asked to, or when it
is user-facing copy for readers of that language.
