# ROSTER — who does what, on this machine

Directives and skills name ROLES. This file binds each role to a concrete
model and access path for this machine, today, and it is the single place a
binding lives: swapping a model is an edit here, a sync of the surfaces
listed under "Binding surfaces", and a `bin/doctor` run. Nothing else may
hardcode a model-to-role assignment.

Three axes, kept apart on purpose:

- **Role**: the job (orchestrate, build, review, research, scout). Stable.
- **Model**: who fills the role. Expected to churn as combos are trialed.
- **Access path**: how the model is reached (Agent-tool subagent, Codex CLI,
  opencode+srt sandbox, cloud). The path fixes billing, sandboxing, and tool
  caps, and it is the axis that grows when a new harness arrives.

## Bindings

| Role | Requires | Model | Access path | Billing |
| --- | --- | --- | --- | --- |
| Orchestrator | judgment tier | Fable 5 (1m) | Claude Code main loop | Anthropic |
| Builder | judgment tier, xhigh | Opus 5 | Agent tool `opus-builder` | Anthropic |
| Researcher / validator | judgment tier, xhigh | Opus 5 | Agent tool `researcher` | Anthropic |
| Scout | volume tier | Sonnet 5 | Explore / general-purpose with `model: sonnet` | Anthropic |

Reviewer portfolio (a set, not a slot — see Selection logic):

| Lane | Model | Access path | Billing |
| --- | --- | --- | --- |
| Codex | GPT-5.x | Codex CLI (`/codex:rescue`) | OpenAI |
| Kimi K3 | K3 | opencode + srt sandbox | Moonshot |
| Opus (opt-in) | Opus 5 | sandboxed claude, or in-session `opus-reviewer` | Anthropic |
| Escalation | /code-review ultra | Claude cloud | Anthropic |

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

A swap must touch every surface that encodes the old binding, in one commit:

- this file
- `agents/*.md` frontmatter (`model:`, `effort:`) for Agent-tool roles
- `bin/doctor` lane checks (review lanes)
- `opus-build/SKILL.md` lane descriptions (until it speaks pure roster)

`bin/doctor` verifies the review lanes against what is actually installed,
and every Agent-tool row of the bindings table against its `agents/*.md`
frontmatter — parsed from this file, so doctor itself never names a model.
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
2. Edit the bindings and every surface above; run `bin/doctor`.
3. Trial period: normal work, combo log accumulating.
4. Decide against the log's baseline; record the outcome; keep or revert.
