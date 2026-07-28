# skills

My personal coding-agent configuration — Claude Code first, plus Codex CLI
and OpenCode. There is no installer, but the wiring is deliberately simple —
a dozen symlinks, documented in [SETUP.md](SETUP.md), with no hardcoded
paths. The persona is mine: fork and edit.

## What's here

- **[AGENT_BEHAVIOR.md](AGENT_BEHAVIOR.md)** — one behavior file for every
  harness. A routing header keys its sections to the harness and model
  actually running (a SHARED core everywhere; model sections for Claude Code;
  a minimal section for harnesses whose own prompts cover less), so each
  session carries only the directives its harness doesn't already enforce.
  Delivered to Claude Code via CLAUDE.md `@`-import and to Codex/OpenCode via
  `AGENTS.md` symlinks.
- **[audit-directives/](audit-directives/SKILL.md)** — the maintenance tool
  for that file. Harness system prompts change under you; this skill snapshots
  them, diffs against the committed copies, and classifies every directive as
  absent, duplicate, or conflict — so directives that stop earning their keep
  get removed instead of silently rotting.
- **[harness-snapshots/](harness-snapshots/README.md)** — the committed
  prompt corpus those audits diff against, with provenance and upstream
  licenses in its README.
- **[bin/fetch-harness-prompts](bin/fetch-harness-prompts)** — deterministic
  snapshot fetcher: a refetch with no upstream change leaves the tree
  byte-identical.
- **[opus-build/](opus-build/SKILL.md)** — budget-split build workflow for
  Anthropic Pro/Max plans: plan and review on the Fable main loop, dispatch
  implementation to Opus subagents at xhigh effort, then breadth-review on
  external harnesses. [review-2026-07-27.md](opus-build/review-2026-07-27.md)
  is the adversarial review from its first validation run.
- **[agents/opus-builder.md](agents/opus-builder.md)** — the pinned-model
  build agent opus-build dispatches to.
- **[statusline.js](statusline.js)** — status line script.
- **[CLAUDE.global.md](CLAUDE.global.md)** — the `~/.claude/CLAUDE.md`
  target: the `@`-import plus a placeholder for durable preferences.

## Wiring

See [SETUP.md](SETUP.md) — everything is symlinks from harness config
directories into this clone.

## Forking

The `### IDENTITY` section of AGENT_BEHAVIOR.md — the R. Daneel Olivaw
persona — is adapted from Bill Burdick's
[zot/humble-master](https://github.com/zot/humble-master) (MIT); rewrite it
to taste. The transferable ideas are the routing header, the audit skill,
and the budget-split workflow.

## License

MIT ([LICENSE](LICENSE)). `harness-snapshots/` contains third-party prompt
text redistributed under upstream licenses — see
[its README](harness-snapshots/README.md).
