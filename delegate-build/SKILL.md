---
name: delegate-build
description: Split build workflow for a judgment-tier main loop (Fable or Opus in Claude Code, GPT-6 Astra in Codex) — plan and review here, implement on fresh builders at the roster's pinned model and effort, breadth-review on external lanes. Use only when the user invokes /delegate-build in Claude Code or $delegate-build in Codex, or asks for it by name, however large the change; the split keeps the main loop's plan and review state hot across a build that outlives one context window or spans several sessions, while builders carry the bulk. Not for work that fits in one sitting (measured 2026-09 in M8, where on a one-session task the split cost about four times solo for equal quality), single-file changes, Q&A, investigation, or sessions on other models.
---

# delegate-build — plan here, build on fresh builders, review here

Before anything else, read the mechanics file for your harness, beside this
SKILL.md: `claude-code.md` in Claude Code, `codex.md` in Codex. It holds the
main-loop model gate, which you apply BEFORE announcing anything, and every
dispatch and lane-invocation mechanic this file leaves out. This file names
roles (builder, scout, researcher, review lanes by lineage); the mechanics
file says which agent and which command fills each. If the SKILL.md text you
were given looks truncated, read SKILL.md from disk.

Why this exists: context continuity. A long build fills a main loop with
reads, edits, and test output until it cycles into fresh sessions that
re-orient from a handoff. Here the plan and judgment state stay hot on the
main loop across the workstream while fresh builders at the roster's pinned
model and effort carry the bulk, whatever model runs the main loop. It does
not save tokens: in M8 (parley, 2026-09) the main loop alone cost more
than a solo run of the same task on the same model. Never advertise a saving.

The model gate exists because Phases 3 and 5 put review and triage on the main
loop, and running those on a weaker model than the builders is a different
workflow; when the gate fails, say so and skip this workflow.

On activation, announce it in plain text ("delegate-build is active") and
briefly narrate phase transitions (dispatching to builders, returning for
review).

Standing rules while active:

- Keep this main loop lean. Don't bulk-read files here; delegate exploration to
  the scout role and keep only conclusions.

## Phase 1 — Plan (here, on the main loop)

1. Resolve ALL ambiguity with the user now: builders are headless, so anything
   unresolved becomes a guess baked into code.
2. Delegate exploration to the scout role. Its pinned model and effort come
   from `roster.conf`, so no per-dispatch override is needed.
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
   will execute), dispatch the researcher role to attack the ORDER, not the
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
never restate context the builder can read itself, AGENT_BEHAVIOR.md (builders
already carry it), or the reporting contract (the builder role carries it).
This loop's own prose (plans, orders, reviews, triage) is the dominant content
it admits, and it recurs every turn. Scope runs both ways: downward, an order carries exactly
what its task's inputs require, no padding; upward, an order whose deliverable
is a synthesis names the goal it must answer, and the deliverable answers it
in target form, never as a concatenation of raw inputs.

## Phase 2 — Build (fresh builders at the roster's pinned model and effort)

Dispatch each order to the builder role. Its pin holds regardless of session
settings. The mechanics file says how to dispatch, and which agents must never
take build work.

Never drop a failed order silently; a missing result is a Phase 3 finding.

Serialize orders that touch the same files; worktree isolation only defers the
merge to a step nobody owns.

Effort: builders run at the roster's pinned effort; don't override it
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
- Anything larger: a narrow fix order to the builder role; don't absorb build
  work here. A fix order has the full Phase 1 shape, **Touches** included,
  scoped to the findings it fixes, and takes the step 4 gate when the fix
  changes protocol, trust, or spec prose. A builder-reported blocker on an editable out-of-scope
  restatement is resolved before work proceeds, by a fix order that widens
  scope or amends the rule, never by shipping the drift; frozen and snapshot
  hits stay report-only.
- Large diff (several hundred lines or more): dispatch the researcher role
  for a criteria-by-criteria verification report (a Validate order: the claim is
  that the diff meets each acceptance criterion) and review that instead.

## Phase 4 — Breadth review (external reviewers)

Lane review runs once as a breadth pass on the branch head here, then once as
a fix review after each Phase 5 fix cycle; Phase 5 runs at most three fix
cycles, so at most four lane rounds in all. Then stop; a round the user
explicitly asks for past that is outside the bound (Phase 5).

First, commit the Phase-3-approved tree (or name the head if already
committed). Right after, announce the roster in plain text, naming that head
SHA and its base: the merge base with the PR's target branch on the breadth
pass, the last lane-reviewed head on a fix review. Every lane request carries
both. Every INSTALLED no-cost lane runs once on each reviewed head (the Claude
lane only if the user opted in). The lane of this loop's own lineage is opt-in
where the mechanics file offers a path to it, and otherwise skipped with kind
`<lane>:own-lineage`. No fixes land between lanes.

Every lane request, breadth pass and fix review alike, carries this method
block verbatim, after the base, the head and what the review is for:

> Method: start from the diff. List the changed files first (`git diff
> --stat <base>...<head>`, over the range this request names) and cover
> each one, so a large file does not crowd out the rest.
> Go through every changed file and every hunk, in order. Do not skip a file
> because it looks minor: docs, specs, skill files, scripts, `bin/`, config
> and tests all count. For each hunk, ask what goes wrong when this code runs
> or this text is followed: wrong logic; an unhandled edge case or error
> path; a security or trust-boundary gap; a concurrency or resource leak; a
> broken contract with callers, with data formats, or with another part of
> this same change; prose (docs, comments, specs, help text) that
> contradicts the code or another part of the change, including counts,
> dates, names and paths the change made stale. When a judgment depends on
> code outside the diff, narrow with grep and glob, then read the exact
> lines.
> Record each finding as soon as you have evidence for it. Do not cap the
> number of findings and do not drop one because others seem more important.
> Bar: each finding is a concrete defect a maintainer would want fixed before
> merge: a wrong behavior, a misleading contract or doc, a real risk. Not
> style, naming or formatting preferences.
> Report one entry per finding: file:line, severity (high, medium or low),
> the defect in one sentence, a concrete failure scenario, and the file:line
> you read that shows it.

Add no word cap, top-N or "most severe only" to it: bound the form, never the
count. Copilot's PR review excludes `bin/` by default, so a lane is the only
line-level reviewer that code gets. Why: in a 2026-10 sample of 45 PRs, lanes
asked for a capped, ranked report returned 1 to 9 findings each, and Copilot
then found on the same heads most of what it reported in round one without
any lane having raised it (13 of 21 where the logs recorded the overlap). In
a backtest on 12 of those PRs, one uncapped `gpt-6.1-sol` pass with this
method, before the two additions below, caught 47% of Copilot's round-one
findings, against 29% for a capped ranked pass. The file-list line and the
stale-facts clause were added after the backtest, aimed at its two
misses, and are untested. Sources:
`notes/copilot-review-gap-2026-10.md`.

Stakes decide whether this phase runs and whether to escalate to the expensive
review the mechanics file names, if it names one, never which no-cost lanes
run: none of them costs Anthropic tokens.

`roster.conf` at the repo root is the single place models and efforts are set.
`bin/doctor` reports which lanes are live; it is not on PATH, so the mechanics
file gives the path that resolves it. An absent tool is a legitimate lane skip
only as a VERIFIED fact: before calling a lane absent, run the check in THIS
session (doctor, or the lane's own `command -v` / plugin lookup) and name it.
In the announcement, name every skipped lane and its kind: "not installed",
"installed but the harness is down", "own-lineage" and "denied" (its run was
refused by the approval step) are different facts.
Dropping an INSTALLED no-cost lane is a judgment call the user can veto, never
silent scaling. If no external lane is available, say so and offer the
in-session fallback the mechanics file names, if it names one (Anthropic-billed,
ask first), or skip the phase.

- **GPT**: the mechanics file says how to invoke it, pin it and confine it.
- **Kimi (via OpenCode)**: the wrapper pins the model (and optional `#variant`
  effort) from `roster.conf` and runs OpenCode 2's `opencode run --standalone`
  under srt: writes confined to OpenCode's state dirs and temp space, network
  to the Kimi API and model catalogs, plus listening on any interface and
  connecting out to loopback (OpenCode 2's private server needs it, so the
  lane does not contain a deliberate escape through a local service; the
  OpenCode service password and Claude Code IDE tokens stay unreadable), repo
  read-only unless it sits under one of those
  writable roots (OpenCode's state dirs, `/tmp`, `/private/tmp`,
  `/private/var/folders`). If srt is missing the wrapper refuses;
  report it and let the user decide, never fall back to a bare
  `opencode run`. "Error starting FSEvents stream" is benign sandbox noise.
  On OpenCode 2 a refused permission returns an error to the reviewer and the
  run goes on (1.x's run-killing auto-reject is gone), but still instruct it:
  read-only tools, and it MUST end with the deliverable. The wrapper tees
  stdout to a temp report file (path on stderr at launch), so a finished
  review survives a killed run.
- **Claude (OPT-IN — costs Anthropic tokens)**: the wrapper runs headless
  `claude -p` under srt, pinned to the model and effort in `roster.conf`,
  read-only at two layers (tool allowlist + OS boundary; for a repo inside a
  path `claude-srt-settings.json` leaves writable, the temp space or
  `~/.claude` outside its denied subdirs, only the allowlist holds), all MCP
  disabled, the same two-layer Director kill as the Kimi lane. Its rubric is the body of
  `agents/claude-reviewer.md`, and it tees stdout like Kimi. If srt is missing,
  take the in-session fallback the mechanics file names and say so; with none,
  the lane is unavailable, and say so. It bills Anthropic tokens, so it is not
  in the default roster: offer it when the user wants an Anthropic-grade pass.

Skipping this phase is allowed only for a change that is low-stakes on every
axis: trust (auth, ownership, input validation, secrets, public routes),
contracts (APIs, payloads, schemas, formats, scripts or prose others
execute), production data and money, state (lifecycle, concurrency, shared
state), and reversibility (obvious, caught by tests, trivially undone). One
failing axis and the lanes run, even on a three-line diff: size alone never
justifies the skip. Announce it like a lane skip: say you are skipping Phase
4 and name the axes you checked. A change with nothing to test, such as a spec
or design, cannot take this skip on Phase 3 alone: its stakes are those of the
code it specifies (a design doc that skipped the lanes in 2026-10 then took 13
Copilot rounds).

## Phase 5 — Triage, fix, and fix review (here, on the main loop)

For a run whose Phase 4 ran, the bound below protects one invariant: no line
reaches the PR that no lane has read (a run that took the Phase 4 skip, or
had no lane, has no such guarantee, and its summary says so). Fix code is
where later review rounds come from (2026-10 sample: on the PRs where it
could be measured, 8 of 12 Copilot round-one comments sat on lines written by
lane-driven fixes, and 28% of later-round comments landed on
a line the previous round's fix changed, while a fix round changed a median
7% of the PR's added lines), so every fix cycle ends in a fix review.

Adjudicate every lane's findings together (expect noise). A valid finding is
fixed unless it lies outside the change (pre-existing code or behavior the
change does not touch); only those are deferred, as follow-ups the summary
names. A valid in-scope finding deferred to save a cycle tends to come back
as a billed Copilot comment (on one sampled PR, 3 of Copilot's 5 round-one
comments were lane findings deferred in triage).

A fix cycle: dispatch the accepted fixes to the builder role (one fix order,
or a few that don't overlap). Each fix order fixes by class: for each finding
it names the defect class, and the builder fixes every instance the change is
responsible for, in the lines it adds or modifies and in code whose behavior
it alters (a caller of a contract it changed, a reader of a format it
changed), and reports where it looked; an instance the change neither touches
nor affects is pre-existing, reported, not fixed, and deferred as above.
Review the result as in Phase 3; that review may send back at most one narrow
correction to the same builder, never a new order. Commit the fix tree and
announce the base (the last lane-reviewed head) and the new head.

Then the fix review: every installed no-cost lane (the Claude lane only if the
user opted in) on the fix range, base to new head, with the merge base named
for context. Each request carries the findings this cycle fixed, every
lane's and not only its own, carries Phase 4's method block, and asks for: a
fixed / still-open verdict on each, since base and head alone cannot certify a
closure or separate a regression from an unrelated new issue; defects in the
code the fix wrote or changed, and in callers of what it changed; and the same
defect class elsewhere in the change. Adjudicate its output:

- A finding rejected in triage and re-raised is re-rejected without a new
  cycle; the per-lane tallies cover the breadth pass only, so the combo-log
  note mentions it in `note=`.
- A regression of a fix, an accepted finding still open, or a new valid
  finding inside the change goes into the next fix cycle; one outside the
  change is deferred as above.
- A fix review with nothing to fix closes the loop.

At most three fix cycles, each followed by its fix review. Valid findings from
the third fix review are not fixed within the bound: the summary lists them as
open, for the user to decide on after the run. A fix made past the bound
still gets a fix review before it ships, and a lane round the user explicitly
asks for past the bound
takes the last lane-reviewed head as its base; the combo-log note logs either
as outside the bound.

Summarize: what shipped, who reviewed what, which findings were rejected and
why, and which were deferred as outside the change (a PR description lists
those too; see the `copilot-loop` skill). A run that skipped Phase 4 or had
no lane says plainly that no lane read the change.

Then capture the run's tallies to the combo log, always: one
`director emit --type note --area combo-log` with, per lane, submitted /
accepted / rejected / unique-catch counts, plus builder facts (work orders,
bounces, fix cycles), the valid findings the fix reviews raised, and any
skips with their kind. The record shape lives in
`ROSTER.md`. Future roster decisions run on this log; a run that skips it
leaves no sample. If `director` is not on PATH, put the same record at the end
of the summary instead, under a `combo-log` heading.
