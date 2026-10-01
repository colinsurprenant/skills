# delegate-build on Claude Code — mechanics

The Claude Code half of the delegate-build skill. SKILL.md (beside this file)
holds the workflow and every rule both harnesses follow; this file holds what
only a Claude Code main loop needs: the model gate, Agent-tool dispatch, the
lane invocation paths, and session effort. Read it before announcing.

In Claude Code the roles are Agent-tool agents: the builder is
`delegate-builder`, the scout is `scout`, the researcher is `researcher`, and
the in-session reviewer is `claude-reviewer`.

## Model gate

The main loop must be Fable or Opus. Any other model fails the gate (SKILL.md
says what to do and why).

## Standing rules and Phase 1 — Plan

- Never use `fork` subagents for build work: a fork inherits this session's
  model and whole context and ignores the model override. Build agents are
  fresh `delegate-builder` agents.
- The `scout` agent's frontmatter pins model and effort, rendered from
  `roster.conf` by `bin/roster-render` (`SCOUT_MODEL` / `SCOUT_EFFORT`).
- AGENT_BEHAVIOR.md reaches builders via the @-import in CLAUDE.global.md,
  routed to SHARED.

## Phase 2 — Build

The `delegate-builder` agent's frontmatter pins model and effort, rendered from
`roster.conf` by `bin/roster-render` (`BUILDER_MODEL` / `BUILDER_EFFORT`), so
both hold regardless of session settings.

- Normally: plain Agent calls with `subagent_type: "delegate-builder"` and the
  order as the prompt; independent orders in a single message so they run in
  parallel.
- Staged batches: the Workflow tool (this skill is your Workflow opt-in):

      export const meta = {
        name: 'delegate-build-dispatch',
        description: 'Run build work orders on delegate-builder agents',
        phases: [{ title: 'Build' }],
      }
      const results = await parallel(args.orders.map((o, i) => () =>
        agent(o, { agentType: 'delegate-builder', label: `build:${i}`, phase: 'Build' })
      ))
      return results.map((r, i) => r ?? `ORDER ${i}: NO RESULT — agent died or returned nothing`)

  Pass orders via `args: { orders: [...] }`.
- Never a bare `general-purpose` agent (or a fork): it inherits the session
  model and lacks `delegate-builder`'s effort pin and reporting contract.

Effort: builders run at `BUILDER_EFFORT` from `roster.conf`.

SKILL.md's cycle-two "one narrow correction to the same builder" goes through
`SendMessage` to that builder's agent ID: the send resumes the finished agent
from its transcript with its context intact, where a new Agent call starts
fresh (observed on Claude Code 2.1.286). So dispatch the cycle-two fix order
as a plain Agent call, whose result carries the ID; the Workflow script above
returns report text only.

## Phase 4 — Breadth review

Stakes: the escalation is `/code-review`, described at the end of the lane
list below.

Resolve `bin/doctor` through this skill's symlink:
`"$(cd -P ~/.claude/skills/delegate-build/.. && pwd)/bin/doctor"`.

The lane of this loop's own lineage is the Claude lane, opt-in through the
Claude bullet below. With no external lane available, the in-session fallback
is the `claude-reviewer` agent.

- **GPT (via Codex)**: `/codex:rescue` with a review request naming the base and
  head (ChatGPT plan billing). Frame it as review-only, "report findings; do not
  modify files": the rescue agent is fix-capable and edits unless told not to.
  Model pin, MUST: get `GPT_REVIEWER_MODEL` and `GPT_REVIEWER_EFFORT` through the
  one reader, never by reading `roster.conf` yourself:
  `"$(cd -P ~/.claude/skills/delegate-build/.. && pwd)/bin/roster-get" GPT_REVIEWER_MODEL`
  and the same for `GPT_REVIEWER_EFFORT`; then put `--model <value> --effort <value>`
  in the request text so the rescue agent forwards them verbatim to
  `codex-companion.mjs task` (verified in the plugin's `agents/codex-rescue.md`
  and `commands/rescue.md`; unset, the lane tracks `~/.codex/config.toml`).
  Sandbox: the plugin dispatches with `sandbox: "read-only"` +
  `approvalPolicy: "never"` by default (codex.mjs, plugin v1.0.6), OS-enforced
  via Seatbelt but not absolute: Codex runs rule-approved commands OUTSIDE the
  sandbox, so a `~/.codex/rules` allowlist entry punches through (seen with
  `director emit`). Director is a separate coordination CLI; without it the
  kill costs nothing. The kill is prompt-enforced because the plugin owns the
  spawn: tell the rescue agent to prefix the runtime invocation with `DIRECTOR_BIN=/dev/null` (every
  hook shim honors it), and include in the request: "Never run the `director`
  CLI or any other state-writing command; deliver your complete findings as
  your final message." After a plugin update, re-check the sandbox defaults; a
  change is a roster-level change to surface to the user.
- **Kimi (via OpenCode)**: via Bash with `run_in_background` (or a long
  explicit timeout),
  `~/.claude/skills/delegate-build/sandbox/kimi-review.sh "<review prompt naming
  the base and head>"`.
- **Claude (OPT-IN — costs Anthropic tokens)**: via Bash with
  `run_in_background` (or a long explicit timeout),
  `~/.claude/skills/delegate-build/sandbox/claude-review.sh "<review prompt naming
  the base and head>"`. If srt is missing, dispatch the `claude-reviewer`
  agent in-session instead (same rubric and pins, classifier-gated rather than
  OS-sandboxed) and say so. Offer it when the user wants that pass without
  `/code-review`.
- **`/code-review`**, built into Claude Code, is the EXPENSIVE escalation,
  drawn from the Anthropic plan. Reserve it for high-stakes diffs the user
  explicitly wants deep-reviewed: run it at effort `max` on the branch or PR
  (`--comment` posts the findings on the PR). Its `ultra` level, a multi-agent
  cloud review, only the user can launch: offer it, never attempt it.

## Session effort

- Session effort for the Fable main loop is the user's call: `high` for
  day-to-day orchestration, `xhigh` for sessions centered on hard design work.
  Thinking tokens bill as output tokens, so effort is a real cost lever.
