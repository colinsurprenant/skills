# ROSTER — who does what, on this machine

Directives and skills name ROLES. This file explains the roles, the access
path each one is reached through, and the logic for choosing who fills it.
It holds no values: every model and effort on this machine lives in
`roster.conf` at the repo root, the single place they are set. From there
`bin/roster-render` writes them into `agents/*.md` frontmatter and `bin/doctor`
verifies the result, so swapping a model is an edit to one file plus two
commands. Nothing else may hardcode a model-to-role assignment.

Three axes, kept apart on purpose:

- **Role**: the job (orchestrate, build, review, research, scout). Stable.
- **Model**: who fills the role. Expected to churn as combos are trialed.
- **Access path**: how the model is reached (Agent-tool subagent, Codex CLI,
  opencode+srt sandbox, cloud). The path fixes billing, sandboxing, and tool
  caps, and it is the axis that grows when a new harness arrives.

## Bindings

Model and Effort name the `roster.conf` key that holds the value, never the
value itself.

| Role | Requires | Model | Effort | Access path | Billing |
| --- | --- | --- | --- | --- | --- |
| Orchestrator | judgment tier | (session model) | (user's call) | Claude Code main loop | Anthropic |
| Builder | volume tier | `$BUILDER_MODEL` | `$BUILDER_EFFORT` | Agent tool `delegate-builder` | Anthropic |
| Researcher / validator | judgment tier | `$RESEARCHER_MODEL` | `$RESEARCHER_EFFORT` | Agent tool `researcher` | Anthropic |
| Scout | volume tier | `$SCOUT_MODEL` | `$SCOUT_EFFORT` | Agent tool `scout` | Anthropic |

The Orchestrator row is the session you are already in: its model is chosen at
launch, not set anywhere in this repo, which is why it has no key.

Tier follows the picker in `AGENT_BEHAVIOR.md`: will anyone act on the output
unchecked? The Builder is volume tier because no build order's output is acted
on unchecked: the orchestrator reviews each report, the lanes review the diff,
and triage closes what they find. Effort is still set per role, which is how a
volume-tier builder can run higher than the scout.

Reviewer portfolio (a set, not a slot — see Selection logic):

| Lane | Model @ effort | Access path | Billing |
| --- | --- | --- | --- |
| GPT | `$GPT_REVIEWER_MODEL` @ `$GPT_REVIEWER_EFFORT` | Codex CLI (`/codex:rescue`) | ChatGPT plan |
| Kimi | `$KIMI_REVIEWER_MODEL` @ `$KIMI_REVIEWER_VARIANT` | opencode + srt sandbox | Moonshot |
| Claude (opt-in) | `$CLAUDE_REVIEWER_MODEL` @ `$CLAUDE_REVIEWER_EFFORT` | sandboxed claude, or in-session `claude-reviewer` | Anthropic |
| Escalation | /code-review ultra | Claude cloud | Anthropic |

Lanes are named by lineage, never by the model inside or the access path,
because the portfolio is diversity by lineage and both of those churn. The
lane of the orchestrator's own lineage is opt-in: it adds the least diversity
to a review of that orchestrator's builders' work, and it bills the same quota
the orchestrator runs on.

`$KIMI_REVIEWER_VARIANT` is opencode's provider-specific reasoning effort and may be
empty, which means take the provider default. What value form each key accepts
— alias, full model id, provider slug, effort level — is documented per key in
`roster.conf`, along with the policy behind it: the Anthropic keys hold aliases
so the whole roster floats to the latest release together.

## Selection logic — two kinds, not one

Singleton roles (builder, researcher, scout) are capability-driven: pick the
single best cost-adjusted model. Monoculture is fine. Changing one is a
substitution trial, measured by rework rate (builder: bounced orders, fix
cycles) or spot-check pass rate (researcher).

The reviewer portfolio is diversity-driven: its value is that different
training lineages fail differently. Compose it for lineage coverage at
bounded cost, not by ranking capability. Current lineages: Anthropic
(Claude), OpenAI (GPT), Moonshot (Kimi). A candidate lane earns a slot by
unique catches (accepted findings no other lane caught), not by hit rate
alone; a lane whose accepted findings duplicate another lane's is redundant
however accurate it is.

## Binding surfaces

One surface to edit, two to run:

- `roster.conf` — the only file you edit. Every model and effort on this
  machine is one line in it.
- `bin/roster-render` — writes those values into `agents/*.md` frontmatter
  (`model:`, `effort:`) for the Agent-tool roles.
- `bin/doctor` — verifies the rendered agents against `roster.conf`, checks the
  review lanes against what is actually installed, and prints the pins each
  lane will use.

Nothing parses `roster.conf` itself: `bin/roster-get` is the one reader every
consumer goes through, so validation, duplicate keys, empty values and error
text have a single definition and a broken roster fails identically in
roster-render, doctor and both review wrappers.

Everything else reads `roster.conf` at run time and needs no sync: the
delegate-build GPT lane resolves it through the skill symlink before dispatching
`/codex:rescue`, and both `delegate-build/sandbox/*.sh` wrappers read it on every
invocation. `bin/doctor` reads it too, so doctor itself never names a model.
Run it after every swap. Prose promises drift; doctor does not.

## Combo log — the evidence stream

Roster decisions run on recorded outcomes, not memory. Capture is
unconditional; analysis is on demand (a `researcher` dispatch over the log
when a decision needs it).

Emit one note per delegate-build run at Phase 5 close, and one for any notable
singleton outcome (a bounced work order, a researcher spot-check result):

    director emit --type note --area combo-log "<task>: build=<model> orders=<n> bounced=<n> fix_cycles=<n>; lane <name>: submitted=<n> accepted=<n> rejected=<n> unique=<n>; lane <name>: ...; skips=<lane:kind|none>; note=<one line>"

Record facts (counts and one-line reasons), never derived metrics; metrics
are recomputed at analysis time from the raw notes, so the record shape can
stay stable while the questions change. Per-lane counts cover the Phase 4
breadth pass only, so they describe one tree per lane; the note as a whole may
span a confirming head. The Phase 5 confirming pass does not increment those
counts: it increments `fix_cycles` instead, once per fix cycle actually run and
not per finding. `fix_cycles` counts Phase 5 cycles only, 0 to 2: the triage
fix dispatch after the breadth pass is the first, and the fix order that
follows the confirming pass (reviewed in Phase 3, no further lane round) is
the second and last. A regression, a still-open accepted finding, or a
blocking new finding can each call for that second cycle, and several found on
one pass batch into it. Phase 3 fix orders issued before the breadth pass are
not fix cycles; they count in `bounced`. A deferred follow-up, and any lane
round the user asks for past the bound, go in `note=`. This definition of
`fix_cycles` changed 2026-09-28, so earlier records are not comparable on it.
Lane names changed 2026-09-30 (codex to gpt, k3 to kimi, opus to claude), and
the workflow's name with them (opus-build to delegate-build); analysis over
earlier records maps the old names onto the new.

## Swap procedure

1. Record the intent and the hypothesis (`director emit --type decision`).
2. Edit `roster.conf`; run `bin/roster-render`; run `bin/doctor`; commit
   `roster.conf` and the rendered `agents/*.md` together. Both commands read the
   file through `bin/roster-get`, so a typo in the edit stops the swap at the
   first command with the offending line number rather than half-applying.
3. Trial period: normal work, combo log accumulating.
4. Decide against the log's baseline; record the outcome; keep or revert.
