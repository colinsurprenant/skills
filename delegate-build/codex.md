# delegate-build on Codex — mechanics

The Codex half of the delegate-build skill, read by the Codex main loop.
SKILL.md (beside this file) holds the workflow and every rule both harnesses
follow; this file holds what only a Codex main loop needs. Read it before
announcing, and apply the model gate first.

## Model gate

The main loop must be GPT-6 Astra. If you are running on the builders' model
(Sol) or a weaker one, say so and skip the workflow.

## Launch and sandbox

Run the main loop with `--sandbox workspace-write`. Workers inherit the main
loop's sandbox, and Codex cannot give a worker a narrower one, so scout and
researcher are read-only by their instructions only, not by the sandbox. If
the loop was launched with a different sandbox, tell the user before
dispatching: every worker runs in it. Network is off by default.

## Roles

The Codex agents are `delegate-builder`, `scout` and `researcher`, installed
into `~/.codex/agents` by `bin/install --codex` and pinned from
`CODEX_BUILDER_MODEL` / `CODEX_BUILDER_EFFORT`, `CODEX_SCOUT_MODEL` /
`CODEX_SCOUT_EFFORT` and `CODEX_RESEARCHER_MODEL` /
`CODEX_RESEARCHER_EFFORT` in `roster.conf`. The pins win: never pass `model`
or `reasoning_effort` at spawn. When SKILL.md says builder, scout or
researcher, these are the agents.

## Dispatch

Spawn each order with `spawn_agent`: `agent_type` is the role
(`delegate-builder`, `scout` or `researcher`), `task_name` is a short unique
name per order, `message` is the order, and `fork_turns` is `"none"` always
(the default forks this loop's whole history into the worker).

Never spawn the built-in `default`, `worker` or `explorer` roles, and never
omit `agent_type` (it falls back to `default`): they run unpinned on this
loop's own model. This is the Codex form of the Claude Code side's no-fork,
no-general-purpose rule.

Independent orders spawn in the same turn (4 concurrent slots).
`wait_agent` returns on the FIRST finisher and also on timeout: a timeout is
not a report, so keep waiting until every spawned worker has delivered its
final message. A worker that ends without one is a Phase 3 finding.

Codex spawns only when explicitly told to: this skill is that instruction, so
never do an order's work inline beyond SKILL.md's under-10-minute rule.

Workers load `~/.codex/AGENTS.md` (AGENT_BEHAVIOR.md), so orders never
restate it. Worker hooks fire SubagentStart/SubagentStop, not
SessionStart/Stop, so workers get no Director digest: an order that depends on
a Director decision states it.

## Approval gates

Codex proceeds unless a skill explicitly requires approval, so each point
where SKILL.md waits on the user is a gate here. At every one of these,
stop and wait for the user's answer before going on:

- Resolving ambiguity in Phase 1 requires approval: stop and wait for the user.
- A step 4 finding that needs a user decision requires approval: stop and wait
  for the user.
- The Claude lane opt-in requires approval: stop and wait for the user; ask
  before any use of it, since it bills Anthropic tokens.
- srt missing for the Kimi lane requires approval: report it, then stop and
  wait for the user to decide.
- Dropping an installed lane requires approval: stop and wait for the user.
- Skipping Phase 4 requires approval: name what makes the change low-stakes,
  then stop and wait for the user.
- Deferring versus fixing new findings in Phase 5 requires approval: stop and
  wait for the user.
- Any escalated command requires approval: stop and wait for the user (see
  Escalation).

## Escalation

Run the main loop with approval policy `on-request` (`--ask-for-approval
on-request`); under `never` no escalation can be approved, so if the loop is
running under `never`, say so.

A command that needs network or writes outside the writable roots runs with
`sandbox_permissions: "require_escalated"` and a justification, and the user
approves each one. Never pass `prefix_rule`: approving one with "always"
writes a standing allow rule into `~/.codex/rules`. Never add rules or edit
`~/.codex` config yourself.

These need escalation:

- The Kimi and Claude lane wrappers. srt cannot start inside Codex's Seatbelt
  sandbox (nested `sandbox-exec` fails with exit 71); outside it, the wrapper
  re-confines itself under srt.
- Every git write (add, commit, branch, `worktree add`), because
  workspace-write keeps each writable root's `.git` read-only unless `.git`
  itself is a configured writable root.
- `director emit` for the combo log, only if the sandbox refuses it.

## Long-running lane wrappers

A shell call returns before the command ends. Keep polling the running
command until it exits, then read the report file the wrapper names on stderr
rather than trusting the capped tool output.

## Lanes

- Kimi (runs when installed) and Claude (opt-in, Anthropic-billed: ask first)
  are offered, through `~/.agents/skills/delegate-build/sandbox/kimi-review.sh`
  and `~/.agents/skills/delegate-build/sandbox/claude-review.sh`, each called
  with `"<review prompt naming the base and head>"` and each escalated (see
  Escalation).
- The GPT lane is not offered from Codex. It is this loop's own lineage, and
  no sandboxed path to it exists that does not bill and write a Codex trust
  entry. `bin/doctor` still reports the GPT lane installed (it detects the
  Claude Code plugin): ignore that row here, name the skip in the roster
  announcement, and log it as `gpt:own-lineage`.
- No in-session Claude reviewer fallback exists in Codex: with srt missing the
  Claude lane is unavailable, and you say so.
- `/code-review` is Claude Code only; there is no escalation here.

## Session effort

The Astra main loop's effort is the user's call: `high` for day-to-day
orchestration.

## Doctor and roster paths

`bin/doctor` and `bin/roster-get` are not on PATH. Resolve doctor through this
skill's symlink:
`"$(dirname "$(readlink -f ~/.agents/skills/delegate-build)")/bin/doctor"`.
Read the roster only through `bin/roster-get` beside it, never by reading
`roster.conf` yourself.
