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
| Builder | judgment tier | `$BUILDER_MODEL` | `$BUILDER_EFFORT` | Agent tool `opus-builder` | Anthropic |
| Researcher / validator | judgment tier | `$RESEARCHER_MODEL` | `$RESEARCHER_EFFORT` | Agent tool `researcher` | Anthropic |
| Scout | volume tier | `$SCOUT_MODEL` | (inherited) | Explore / general-purpose with the scout model override | Anthropic |

The Orchestrator row is the session you are already in: its model is chosen at
launch, not set anywhere in this repo, which is why it has no key.

Reviewer portfolio (a set, not a slot — see Selection logic):

| Lane | Model @ effort | Access path | Billing |
| --- | --- | --- | --- |
| Codex | `$CODEX_MODEL` @ `$CODEX_EFFORT` | Codex CLI (`/codex:rescue`) | ChatGPT plan |
| Kimi K3 | `$K3_MODEL` @ `$K3_VARIANT` | opencode + srt sandbox | Moonshot |
| Opus (opt-in) | `$OPUS_REVIEWER_MODEL` @ `$OPUS_REVIEWER_EFFORT` | sandboxed claude, or in-session `opus-reviewer` | Anthropic |
| Escalation | /code-review ultra | Claude cloud | Anthropic |

`$K3_VARIANT` is opencode's provider-specific reasoning effort and may be
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
bounded cost, not by ranking capability. Current lineages: Anthropic,
OpenAI, Moonshot. A candidate lane earns a slot by unique catches (accepted
findings no other lane caught), not by hit rate alone; a lane whose accepted
findings duplicate another lane's is redundant however accurate it is.

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
opus-build Codex lane resolves it through the skill symlink before dispatching
`/codex:rescue`, and both `opus-build/sandbox/*.sh` wrappers read it on every
invocation. `bin/doctor` reads it too, so doctor itself never names a model.
Run it after every swap. Prose promises drift; doctor does not.

## Combo log — the evidence stream

Roster decisions run on recorded outcomes, not memory. Capture is
unconditional; analysis is on demand (a `researcher` dispatch over the log
when a decision needs it).

Emit one note per opus-build run at Phase 5 close, and one for any notable
singleton outcome (a bounced work order, a researcher spot-check result):

    director emit --type note --area combo-log "<task>: build=<model> orders=<n> bounced=<n> fix_cycles=<n>; lane <name>: submitted=<n> accepted=<n> rejected=<n> unique=<n>; lane <name>: ...; skips=<lane:kind|none>; note=<one line>"

Record facts (counts and one-line reasons), never derived metrics; metrics
are recomputed at analysis time from the raw notes, so the record shape can
stay stable while the questions change.

## Swap procedure

1. Record the intent and the hypothesis (`director emit --type decision`).
2. Edit `roster.conf`; run `bin/roster-render`; run `bin/doctor`; commit
   `roster.conf` and the rendered `agents/*.md` together. Both commands read the
   file through `bin/roster-get`, so a typo in the edit stops the swap at the
   first command with the offending line number rather than half-applying.
3. Trial period: normal work, combo log accumulating.
4. Decide against the log's baseline; record the outcome; keep or revert.
