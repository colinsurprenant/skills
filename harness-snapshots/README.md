# harness-snapshots

Verbatim system prompts of the coding-agent harnesses used alongside Claude
Code, committed so that `git diff harness-snapshots/` works as a drift
detector for [AGENT_BEHAVIOR.md](../AGENT_BEHAVIOR.md) (see the
[audit-directives skill](../audit-directives/SKILL.md)).
`bin/fetch-harness-prompts` regenerates them; the output carries no
timestamps, so a refetch with no upstream change leaves the tree
byte-identical.

## Provenance and licensing

These files are third-party content, redistributed under their upstream
licenses. Copyright remains with their authors.

- `codex/` — prompts embedded in the locally installed
  [Codex CLI](https://github.com/openai/codex) binary (Apache-2.0).
  `metadata.json` records the binary hash, architecture, and which prompt
  file the configured model actually receives.
- `opencode/` — prompt files fetched from
  [sst/opencode](https://github.com/sst/opencode) (MIT). `metadata.json`
  records the exact upstream commit.
- `claude-code/` — intentionally absent. Anthropic does not publish the
  Claude Code system prompt, and a snapshot of it embeds machine-specific
  paths; the audit skill generates it locally from inside a live session,
  and the directory is gitignored.

## Related

[elder-plinius/CL4R1T4S](https://github.com/elder-plinius/CL4R1T4S) is the
large public corpus of extracted system prompts, useful for cross-checking
model-level prompt language. Nothing from it is vendored here: the collection
is AGPL-3.0 (incompatible with this repo's MIT), and it covers a different
surface for our purposes — its current Anthropic files are claude.ai model
prompts, and its newest Claude Code artifact predates the harnesses audited
here.
