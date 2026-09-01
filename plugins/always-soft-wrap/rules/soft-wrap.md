# Soft wrap

Never hard-wrap prose. A paragraph — and any sentence inside one — is a single line in the file, however long. Rendering long lines is the job of the reader's editor (soft wrap); a line break typed into the middle of a sentence bakes one editor's width into the file and turns every future edit into a re-wrapping diff.

This applies to every prose file you write or edit: Markdown and plain text — READMEs, documentation, skill and rule files, changelogs, manuals, notes. A list item is one line too, including what would otherwise be its indented continuation; so is a blockquote paragraph. It applies equally to prose that travels through tools rather than files, such as issue descriptions and memory entries.

Unaffected: code and the contents of fenced code blocks; comments inside source code, which follow that language's style and whatever line length its formatter enforces; heading, table and list structure; YAML frontmatter; and real structural breaks — a blank line between paragraphs, a new list item, a new section. A commit message body keeps git's conventional wrapping at ~72 columns, because it is read by tools that do not soft wrap.

When you edit a paragraph that is already hard-wrapped, re-flow that paragraph into a single line as part of the edit. Do not sweep through files you were not asked to touch just to re-flow them — in a shared repository that tramples other people's diffs. Re-flow follows the edit; it does not go looking for work.
