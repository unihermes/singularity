Read `CLAUDE.md` for the project map, conventions and checks.
Use `python3 tools/context.py` for a compact live inventory; pass a directory
or file to narrow it (`qs` abbreviates the Quickshell root). File output lists
imports and declarations with line numbers so only relevant ranges need reading.
Commit cohesive changes after relevant checks pass; keep unrelated work out of commits.

For all mockups, use self-contained interactive HTML artifacts in the conversation,
as in the style exploration: named choices and working local controls when useful.
Follow the real project design guidance and check layout and interactions.
Do not commit mockup files or mockup-only supporting files.
Read `docs/MOCKUPS.md` before making one: combinable switches tagged Settings / New /
Preview, a keep-current reset, comments per page and copyable picks; real tokens and
sizes; check what already exists first. The starter template is at
`~/.claude/projects/-home-giordano-Singularity/memory/mockup-template.html` (not in the repo).
