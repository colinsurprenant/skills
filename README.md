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
  [opus-build/sandbox/](opus-build/sandbox/) is the OS-level sandbox wrapper
  for its open-weight review lane — see Sandboxing below.
- **[agents/opus-builder.md](agents/opus-builder.md)** — the pinned-model
  build agent opus-build dispatches to.
- **[statusline.js](statusline.js)** — status line script.
- **[CLAUDE.global.md](CLAUDE.global.md)** — the `~/.claude/CLAUDE.md`
  target: the `@`-import plus a placeholder for durable preferences.

## Sandboxing

Agents here run under OS-level confinement (macOS Seatbelt), scoped by trust
and supervision rather than model goodwill:

- The opus-build **K3 reviewer** — an open-weight model running headless
  through OpenCode, which has no OS sandbox of its own — is wrapped in
  Anthropic's [`@anthropic-ai/sandbox-runtime`](https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime)
  by [opus-build/sandbox/k3-review.sh](opus-build/sandbox/k3-review.sh):
  repo readable but not writable, writes confined to OpenCode's own state
  dirs and temp space, network confined to the Kimi API. Fails closed when
  srt is missing rather than degrading to an unsandboxed run.
- The **Codex reviewer** is OS-sandboxed read-only by its plugin's own
  default — pinned in the opus-build skill so a plugin update that widens
  that default gets surfaced, not silently absorbed.
- **Everything else** — the main loop and Opus build subagents — runs through
  Claude Code's native Bash sandbox, enabled in settings (see
  [SETUP.md](SETUP.md)): auto-allow inside the boundary, a visible prompt
  for any unsandboxed escape.

The premise: a git worktree is merge hygiene, not a security boundary — any
agent that runs `npm install` or a test suite executes third-party code with
your whole account. So the boundary is mechanical wherever a lane runs
headless or on a model without Claude's safety training; permission prompts
only govern sessions a human is actually watching. Sandboxing is also an
enabler, not just a shield: inside the boundary, commands auto-run without
permission friction.

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
