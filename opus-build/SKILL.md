---
name: opus-build
description: Split build workflow for Fable or Opus sessions — plan and review on the main loop, implement on fresh Opus subagents at xhigh effort. Use when this session runs on Fable or Opus and is about to implement a feature, fix, or refactor of substance — multiple files, new code paths, or a change that needs a test cycle — even if the user doesn't mention budget, Opus, or delegation. On a Fable main loop it is a budget split; on an Opus main loop it is a context split. Not for single-file changes of a few lines, pure Q&A, investigation-only tasks, or sessions on any other model.
---

# opus-build — plan here, build on Opus, review here

Why this exists: the token-heavy part of a coding task is the build loop (file
reads, edits, test runs); the judgment-heavy parts are planning and review.
Split accordingly: judgment stays on this main loop, volume goes to fresh Opus
agents. The split pays for two different reasons, and which one applies depends
on the model running this session.

- **Fable main loop — budget split.** Pro/Max plans have ONE shared weekly
  usage pool. Fable drains it at ~2x Opus's rate, and Fable usage is
  additionally capped at 50% of the weekly limit. Moving build volume onto
  Opus protects the scarce half.
- **Opus main loop — context split.** The budget argument does NOT apply: same
  model, same pool, so delegating saves no tokens, and claiming otherwise
  would be false. The structure still pays for reasons that were always true
  and merely secondary on Fable — builders start on fresh context instead of
  inheriting a loaded main loop, independent orders run in parallel, and this
  loop stays lean enough to review well. Run the full workflow; just don't
  advertise a saving that isn't there.

On any other model, say so and skip this workflow. The budget premise doesn't
hold, and Phases 3 and 5 put review and triage on the main loop — running those
on a weaker model than the builders is a different workflow, not this one.

On activation, announce it in plain text naming the mode, e.g. "opus-build is
active (Fable main loop: budget split)" or "opus-build is active (Opus main
loop: context split, no budget saving)". Briefly narrate the phase transitions
— dispatching to Opus builders, returning here for review — so activation is
never silent.

Two standing rules while this skill is active:

- Keep this main loop lean. Don't bulk-read files here — delegate exploration
  to Explore agents and keep only conclusions in context. Every token read into
  this context gets re-read on every subsequent turn.
- Never use `fork` subagents for build work — a fork inherits this session's
  model AND its whole context, which defeats the split in either mode (and on
  Fable it ignores the model override too, leaking volume onto the capped
  half). Build agents are fresh agents with `model: opus`.

## Phase 1 — Plan (here, on the main loop)

1. Resolve ALL ambiguity with the user now. Build agents run headless and cannot
   ask questions; anything left unresolved becomes a guess baked into code.
2. Delegate codebase exploration to Explore agents.
3. Write one work order per independent workstream. A work order is self-contained:
   - **Goal** — what to build and why (one sentence of intent).
   - **Scope** — files/modules to touch; what is explicitly out of scope.
   - **Constraints** — contracts to preserve, existing patterns to follow (name the files).
   - **Acceptance criteria** — observable, checkable statements.
   - **Verification** — exact test/build commands to run.

The work order stays pure task content: AGENT_BEHAVIOR.md reaches builders
automatically via the @-import in CLAUDE.global.md (its routing header scopes
subagents to SHARED), and the `opus-builder` agent definition (committed
alongside this skill) carries the reporting contract — so neither needs
repeating in every order.

## Phase 2 — Build (Opus, xhigh)

Dispatch each work order to the `opus-builder` agent. Its definition pins
`model: opus` and `effort: xhigh` in frontmatter, so both guarantees hold
regardless of session settings.

- One or a few orders: plain Agent calls with `subagent_type: "opus-builder"`
  and the work order as the prompt. Send independent orders in a single message
  so they run in parallel.
- Larger batches needing staged orchestration: the Workflow tool (this skill's
  instruction is your Workflow opt-in):

      export const meta = {
        name: 'opus-build-dispatch',
        description: 'Run build work orders on opus-builder agents',
        phases: [{ title: 'Build' }],
      }
      const results = await parallel(args.orders.map((o, i) => () =>
        agent(o, { agentType: 'opus-builder', label: `build:${i}`, phase: 'Build' })
      ))
      return results.map((r, i) => r ?? `ORDER ${i}: NO RESULT — agent died or returned nothing`)

  Pass the work orders via `args: { orders: [...] }`. Never drop a failed order
  silently — a missing result is itself a finding for Phase 3.
- Never `fork`. Never a bare `general-purpose` agent either: on Fable it
  inherits Fable and leaks volume onto the capped half; on Opus it inherits the
  right model but not `opus-builder`'s xhigh pin or its reporting contract.

Serialize orders that would touch the same files: if two orders conflict, they
weren't independent workstreams, and worktree isolation would only defer the
merge conflict to a step nobody owns.

Effort policy: always `xhigh` for builders — Anthropic's model guidance names
xhigh the best effort for coding and agentic work, and deeper thinking on the
first pass is cheaper than a redispatch loop mediated by this main loop. On a
Fable main loop there is a second reason: Opus is the cheap half of the pool.
The agent definition enforces this; don't override it downward per order.

## Phase 3 — First review (here, on the main loop)

Review the diff against the acceptance criteria, not from scratch: spec
mismatches, scope creep, missed criteria, suspicious test output. This pass is
the one no external reviewer can do — only this session knows the intent.

- Trivial fix (typo-grade): fix inline.
- Anything more: write a narrow fix order and redispatch to Opus. Don't absorb
  build work back into this main loop.
- Large diff (several hundred lines or more): don't pull it all into this
  context — dispatch an Opus agent to produce a criteria-by-criteria
  verification report and review that instead.

## Phase 4 — Breadth review (external reviewers)

Once the diff passes Phase 3, run independent fresh-eyes passes in parallel.
Stakes scale whether this phase runs and whether to escalate to /code-review —
not the no-cost roster: when the phase runs, every no-cost lane that is
INSTALLED runs, since none of them costs Anthropic tokens.

`ROSTER.md` at the repo root is the canonical role-to-model binding; the
lanes below are its reviewer portfolio as currently bound. The roster is
what this machine actually has, not a fixed list — `bin/doctor`
in the skills clone reports which lanes are live; it is not on PATH, so
resolve it through this skill's own symlink:
`"$(dirname "$(readlink -f ~/.claude/skills/opus-build)")/bin/doctor"`. A tool
that isn't installed is a legitimate reason to skip its lane and needs no
veto — but only as a VERIFIED fact, never an assumption. Before calling a lane
absent, run the check in THIS session (doctor as above, or that lane's own
`command -v` / plugin lookup) and name the check you ran. An unverified "not installed" is exactly the silent
scaling this rule exists to prevent, wearing a more respectable hat. What
still needs saying out loud: announce the roster in plain text on entering
this phase, and name any lane you skipped along with which kind of skip it
was — "not installed" and "installed but the harness is down" are different
facts and the user should get the right one. Dropping an INSTALLED no-cost reviewer remains a
judgment call the user gets to veto, not silent scaling. If no external lane is
available at all, say so and either offer the in-session `opus-reviewer` agent
(Anthropic-billed, so ask first) or skip the phase.

- **Codex**: `/codex:rescue` with a review request on the diff (OpenAI billing).
  Frame it explicitly as review-only — "report findings; do not modify files" —
  the rescue agent is fix-capable and will edit if not told otherwise.
  Sandbox pin: the plugin dispatches with `sandbox: "read-only"` +
  `approvalPolicy: "never"` by default (verified in codex.mjs, plugin v1.0.6) —
  OS-enforced via Seatbelt, so this reviewer mechanically cannot write. After a
  plugin update, re-check those defaults; a change there is a roster-level
  change to surface to the user, not silently absorb.
- **Kimi K3 (via OpenCode)**: invoke through the sandbox wrapper bundled with
  this skill — `~/.claude/skills/opus-build/sandbox/k3-review.sh "<review
  prompt naming the diff/branch>"` — via Bash with `run_in_background` (or a
  long explicit timeout): a real review run exceeds the default Bash timeout.
  The wrapper pins `-m kimi-for-coding/k3` and runs `opencode run` under srt
  (`@anthropic-ai/sandbox-runtime`): writes confined to OpenCode's own state
  dirs + temp space, network confined to the Kimi API + models.dev, repo
  readable but not writable. This lane needs the mechanical boundary: OpenCode
  has no OS-level sandbox of its own, and it runs an open-weight model
  headless. If srt is missing, the wrapper refuses to run — report that and
  let the user decide; never fall back to a bare `opencode run` silently.
  Benign noise from the sandbox: "Error starting FSEvents stream" (Seatbelt
  blocks file watching; a headless review doesn't need it). Gotcha:
  `opencode run` can exit 0 with NO final message when a permission
  auto-reject kills the run (e.g. a `cd` outside the project) — instruct the
  reviewer: no `cd`, read-only tools, and it MUST end with the deliverable.
  A native kimi CLI harness is a planned future addition (tracked as a GitHub
  issue).
- **Opus (OPT-IN — costs Anthropic tokens)**: invoke through the sandbox
  wrapper bundled with this skill —
  `~/.claude/skills/opus-build/sandbox/opus-review.sh "<review prompt naming
  the diff/branch>"` — via Bash with `run_in_background` (or a long explicit
  timeout): a real review run exceeds the default Bash timeout. The wrapper
  runs headless `claude -p` under srt, pinned to `--model claude-opus-5
  --effort xhigh`, read-only at two layers (tool allowlist + OS boundary),
  with all MCP disabled and the same two-layer Director kill as the K3 lane.
  Reviewers never need write access, so the boundary costs nothing — it is
  least privilege, not distrust of Opus, and it keeps every review lane under
  one mechanically-enforced posture. The rubric is single-sourced: the
  wrapper strips the frontmatter from `agents/opus-reviewer.md` and uses that
  body as its prompt preamble, so the two Opus lanes cannot drift. If srt is
  missing the wrapper refuses to run — fall back to dispatching the
  `opus-reviewer` agent in-session (same rubric, same model/effort pins,
  classifier-gated instead of OS-sandboxed) and say that is what you did.
  Unlike Codex/K3 this lane BILLS the Opus half of the shared Anthropic pool,
  so it is not part of the default roster — offer it when the user wants an
  Anthropic-grade fresh-eyes pass without escalating to /code-review.
- **`/code-review:code-review`** is the EXPENSIVE escalation — its agents bill
  Anthropic-side. Reserve it for high-stakes diffs the user explicitly wants
  deep-reviewed.

Skipping this phase entirely is allowed for low-stakes changes — Phase 3 plus
passing tests is enough — but the skip takes the same shape as a lane skip:
say you are skipping Phase 4 and name what makes the change low-stakes (size,
blast radius, reversibility), so the call is visible and vetoable. An
unannounced phase skip is the lane-level silent scaling this skill already
forbids, one grain coarser.

## Phase 5 — Triage and close (here, on the main loop)

Adjudicate external findings (expect noise), dispatch real fixes to Opus, then
summarize: what shipped, who reviewed what, which findings were rejected and why.

Then capture the run's tallies to the combo log, always: one
`director emit --type note --area combo-log` with, per lane, submitted /
accepted / rejected / unique-catch counts, plus builder facts (work orders,
bounces, fix cycles) and any skips with their kind. The record shape lives in
`ROSTER.md`. The summary prose is for the user; the combo log is the evidence
future roster decisions run on — a run that skips it leaves no sample.

## Budget hygiene (Fable main loop only)

In context-split mode there is no budget claim to verify: same model, same pool.
These apply when the main loop is Fable.

- First few uses: ask the user to check `/usage` — the build volume must appear
  under Opus, not Fable. This attribution is not confirmed anywhere in the
  docs: if build volume lands under Fable, the budget split saves nothing —
  stop, tell the user, and drop the delegation until the mechanics are
  understood.
- Session effort for the Fable main loop is the user's call: `high` for
  day-to-day orchestration, `xhigh` for sessions centered on hard design work.
  Thinking tokens bill as output tokens, so effort is a real Fable-budget lever.
