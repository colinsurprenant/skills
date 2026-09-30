---
name: opus-build
description: Split build workflow for a Fable or Opus main loop — plan and review here, implement on fresh Opus builders at the roster's pinned effort, breadth-review on external lanes. Use only when the user invokes /opus-build or asks for it by name, however large the change; the split keeps the main loop's plan and review state hot across a build that outlives one context window or spans several sessions, while builders carry the bulk. Not for work that fits in one sitting (measured 2026-09 in M8, where on a one-session task the split cost about four times solo for equal quality), single-file changes, Q&A, investigation, or sessions on other models.
---

# opus-build — plan here, build on Opus, review here

Why this exists: context continuity. A long build fills a main loop with
reads, edits, and test output until it cycles into fresh sessions that
re-orient from a handoff. Here the plan and judgment state stay hot on the
main loop across the workstream while fresh Opus builders carry the bulk,
whatever model runs the main loop. It does not save tokens: in M8 (parley,
2026-09) the Fable main loop alone cost more than a Fable solo run of the
same task. Never advertise a saving.

On any other model, say so and skip this workflow: Phases 3 and 5 put review
and triage on the main loop, and running those on a weaker model than the
builders is a different workflow.

On activation, announce it in plain text ("opus-build is active") and briefly
narrate phase transitions (dispatching to builders, returning for review).

Standing rules while active:

- Keep this main loop lean. Don't bulk-read files here; delegate exploration to
  Explore agents and keep only conclusions.
- Never use `fork` subagents for build work: a fork inherits this session's
  model and whole context and ignores the model override. Build agents are
  fresh `opus-builder` agents.

## Phase 1 — Plan (here, on the main loop)

1. Resolve ALL ambiguity with the user now: builders are headless, so anything
   unresolved becomes a guess baked into code.
2. Delegate exploration to Explore agents, with the `model` override taken from
   the roster on every scout:
   `"$(dirname "$(readlink -f ~/.claude/skills/opus-build)")/bin/roster-get SCOUT_MODEL"`.
3. Write the work orders. Each is self-contained:
   - **Goal** — what to build and why (one sentence of intent).
   - **Scope** — files/modules to touch; what is explicitly out of scope.
   - **Constraints** — contracts to preserve, patterns to follow (name the files).
   - **Acceptance criteria** — observable, checkable statements.
   - **Verification** — exact test/build commands, or for a prose deliverable
     the exact check that demonstrates each criterion (a grep, a `--check`
     mode, a line to read).
   - **Touches** — the rule, contract, or term this order changes, named so the
     builder can find every restatement (the sweep is the builder's standing
     behavior). `none` is legal and turns the sweep off.
4. When the work is protocol-, trust-, or spec-to-prose-shaped (rules naming
   who may do what, text other documents must agree with, prose another party
   will execute), dispatch the `researcher` agent to attack the ORDER, not the
   code: what it lets a builder get wrong, which rule keys on a peer-supplied
   input, which sibling documents drift when it lands. Make it a Validate order
   whose claim is "a builder executing this order as written produces what the
   user wants", and include the user's original request and the step 1
   decisions, since the order alone cannot reveal a requirement it dropped.
   It reports a verdict on the claim plus the defect list supporting it.
   Fold the findings in; a finding that needs a user decision reopens step 1
   before dispatch. Only orders that are code all the way through, with tests
   as the check, skip this gate; any protocol, trust, or spec-prose part turns
   it on, and in a prose repo it is on for most orders by design.

Granularity. A work order is a coherent slice a solo session would finish in
15 to 30 minutes, never a step. Two or three dispatches per session is the
norm; needing more means the cut is wrong or the task should have stayed
inline. Anything a solo session finishes in under 10 minutes, do here.
Narrow fix orders (Phases 3 and 5) are exempt from the 15-minute floor.
Independent orders may run concurrently. Why: each builder pays a fixed
orientation cost (~1.4 USD measured in M8) and each dispatch costs this loop
4 to 13 messages of coordination.

Write less. An order states what to do, what to touch, and what to report;
never restate context the builder can read itself, AGENT_BEHAVIOR.md (it
reaches builders via the @-import in CLAUDE.global.md, routed to SHARED), or
the reporting contract (`opus-builder` carries it). This loop's own prose
(plans, orders, reviews, triage) is the dominant content it admits, and it
recurs every turn. Scope runs both ways: downward, an order carries exactly
what its task's inputs require, no padding; upward, an order whose deliverable
is a synthesis names the goal it must answer, and the deliverable answers it
in target form, never as a concatenation of raw inputs.

## Phase 2 — Build (Opus builders at the roster's pinned effort)

Dispatch each order to the `opus-builder` agent. Its frontmatter pins model and
effort, rendered from `roster.conf` by `bin/roster-render` (`BUILDER_MODEL` /
`BUILDER_EFFORT`), so both hold regardless of session settings.

- Normally: plain Agent calls with `subagent_type: "opus-builder"` and the order
  as the prompt; independent orders in a single message so they run in
  parallel.
- Staged batches: the Workflow tool (this skill is your Workflow opt-in):

      export const meta = {
        name: 'opus-build-dispatch',
        description: 'Run build work orders on opus-builder agents',
        phases: [{ title: 'Build' }],
      }
      const results = await parallel(args.orders.map((o, i) => () =>
        agent(o, { agentType: 'opus-builder', label: `build:${i}`, phase: 'Build' })
      ))
      return results.map((r, i) => r ?? `ORDER ${i}: NO RESULT — agent died or returned nothing`)

  Pass orders via `args: { orders: [...] }`. Never drop a failed order
  silently; a missing result is a Phase 3 finding.
- Never a bare `general-purpose` agent (or a fork): it inherits the session
  model and lacks `opus-builder`'s effort pin and reporting contract.

Serialize orders that touch the same files; worktree isolation only defers the
merge to a step nobody owns.

Effort: builders run at `BUILDER_EFFORT` from `roster.conf`; don't override it
downward per order. A fixed pin on the first pass is cheaper than a redispatch
loop through this main loop.

## Phase 3 — First review (here, on the main loop)

Review against the acceptance criteria, not from scratch: spec mismatches,
scope creep, missed criteria, suspicious test output; only this session knows
the intent. Review by report: read the builder's hand-back and make targeted
reads of the lines it names, never the whole diff (measured in M8 to hold).

- A review fix a solo pass finishes in under 10 minutes: do it here, inline,
  under the same obligations an order would carry: the step 4 gate when it
  changes protocol, trust, or spec prose; the restatement sweep; and the
  verification the order would have named.
- Anything larger: a narrow fix order to `opus-builder`; don't absorb build work here. A
  fix order has the full Phase 1 shape, **Touches** included, scoped to the
  findings it fixes, and takes the step 4 gate when the fix changes protocol,
  trust, or spec prose. A builder-reported blocker on an editable out-of-scope
  restatement is resolved before work proceeds, by a fix order that widens
  scope or amends the rule, never by shipping the drift; frozen and snapshot
  hits stay report-only.
- Large diff (several hundred lines or more): dispatch an Opus agent for a
  criteria-by-criteria verification report and review that instead.

## Phase 4 — Breadth review (external reviewers)

Lane review runs at most twice per build: one breadth pass on the branch head
here, and one confirming pass on the fixed head in Phase 5. Then stop; a
round the user explicitly asks for past that is outside the bound (Phase 5).

First, commit the Phase-3-approved tree (or name the head if already
committed). Right after, announce the roster in plain text, naming that head
SHA and its base: the merge base with the PR's target branch on the breadth
pass, the breadth-pass head on the confirming pass. Every lane request carries
both. Every INSTALLED no-cost lane runs once on the breadth head (the Opus lane
only if the user opted in); the confirming pass runs the lane set Phase 5
names. No fixes land between lanes.

Stakes decide whether this phase runs and whether to escalate to /code-review,
never which no-cost lanes run: none of them costs Anthropic tokens.

`roster.conf` at the repo root is the single place models and efforts are set.
`bin/doctor` reports which lanes are live; it is not on PATH, so resolve it
through this skill's symlink:
`"$(dirname "$(readlink -f ~/.claude/skills/opus-build)")/bin/doctor"`. An
absent tool is a legitimate lane skip only as a VERIFIED fact: before calling
a lane absent, run the check in THIS session (doctor, or the lane's own
`command -v` / plugin lookup) and name it. In the announcement, name every
skipped lane and its kind: "not installed" and "installed but the harness is
down" are different facts. Dropping an INSTALLED no-cost lane is a judgment
call the user can veto, never silent scaling. If no external lane is available,
say so and offer the in-session `opus-reviewer` agent (Anthropic-billed, ask
first) or skip the phase.

- **Codex**: `/codex:rescue` with a review request naming the base and head
  (ChatGPT plan billing). Frame it as review-only, "report findings; do not
  modify files": the rescue agent is fix-capable and edits unless told not to.
  Model pin, MUST: get `CODEX_MODEL` and `CODEX_EFFORT` through the one reader,
  never by reading `roster.conf` yourself:
  `"$(dirname "$(readlink -f ~/.claude/skills/opus-build)")/bin/roster-get CODEX_MODEL"`
  and the same for `CODEX_EFFORT`; then put `--model <value> --effort <value>`
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
- **Kimi K3 (via OpenCode)**: via Bash with `run_in_background` (or a long
  explicit timeout),
  `~/.claude/skills/opus-build/sandbox/k3-review.sh "<review prompt naming the
  base and head>"`. The wrapper pins the model (and optional `--variant`
  effort) from `roster.conf` and runs `opencode run` under srt: writes
  confined to OpenCode's state dirs and temp space, network to the Kimi API
  and model catalogs, repo read-only. If srt is missing the wrapper refuses;
  report it and let the user decide, never fall back to a bare
  `opencode run`. "Error starting FSEvents stream" is benign sandbox noise.
  Gotcha: `opencode run` can exit 0 with NO final message when
  a permission auto-reject kills the run (e.g. a `cd` outside the project), so
  instruct the reviewer: no `cd`, read-only tools, and it MUST end with the
  deliverable. The wrapper tees stdout to a temp report file (path on stderr
  at launch), so a finished review survives a killed run.
- **Opus (OPT-IN — costs Anthropic tokens)**: via Bash with
  `run_in_background` (or a long explicit timeout),
  `~/.claude/skills/opus-build/sandbox/opus-review.sh "<review prompt naming
  the base and head>"`. The wrapper runs headless `claude -p` under srt, pinned
  to the model and effort in `roster.conf`, read-only at two layers (tool
  allowlist + OS boundary), all MCP disabled, the same two-layer Director kill
  as K3. Its rubric is the body of `agents/opus-reviewer.md`, and it tees
  stdout like K3. If srt is missing, dispatch the `opus-reviewer` agent in-session instead (same
  rubric and pins, classifier-gated rather than OS-sandboxed) and say so. It
  bills Anthropic tokens, so it is not in the default roster: offer it when
  the user wants an Anthropic-grade pass without /code-review.
- **`/code-review:code-review`** is the EXPENSIVE escalation, billed
  Anthropic-side. Reserve it for high-stakes diffs the user explicitly wants
  deep-reviewed.

Skipping this phase is allowed for low-stakes changes (Phase 3 plus passing
tests), but announce it like a lane skip: say you are skipping Phase 4 and
name what makes the change low-stakes (size, blast radius, reversibility).

## Phase 5 — Triage and close (here, on the main loop)

Adjudicate every lane's findings together (expect noise), dispatch the accepted
fixes to `opus-builder` as cycle one (one fix order, or a few that don't overlap), commit
the fix tree, and announce the base (the breadth head) and the new head.

Then run ONE confirming pass: only the lanes whose findings were accepted,
each request carrying that lane's accepted findings and asking for a fixed /
still-open verdict on each, since base and head alone cannot certify a
closure or separate a regression from an unrelated new issue.
Adjudicate its output:

- A finding rejected in triage and re-raised is re-rejected without a new
  cycle and counted in the rejected tally.
- A new finding that is not a regression goes into the summary as a deferred
  follow-up unless the user says otherwise; a blocking one (a security or
  correctness defect that would not ship as a follow-up) is fixed instead.
- A regression of a fix, or an accepted finding still open, is fixed, never
  deferred.

Fixes from the confirming pass go out as one fix order, cycle two and the
last. Its Phase 3 review belongs to cycle two and may send back at most one
narrow correction to the same builder, never a new order. Anything still open
after that goes into the summary as open, not fixed, and the summary says
which fixes no lane re-reviewed. A lane round the user explicitly asks for
after that is outside the bound: its base is the confirming head, and the
combo-log note logs it as such.

Summarize: what shipped, who reviewed what, which findings were rejected and
why.

Then capture the run's tallies to the combo log, always: one
`director emit --type note --area combo-log` with, per lane, submitted /
accepted / rejected / unique-catch counts, plus builder facts (work orders,
bounces, fix cycles) and any skips with their kind. The record shape lives in
`ROSTER.md`. Future roster decisions run on this log; a run that skips it
leaves no sample.

## Session effort

- Session effort for the Fable main loop is the user's call: `high` for
  day-to-day orchestration, `xhigh` for sessions centered on hard design work.
  Thinking tokens bill as output tokens, so effort is a real cost lever.
