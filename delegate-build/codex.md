# delegate-build on Codex — mechanics

The Codex half of the delegate-build skill, read by the Codex main loop.
SKILL.md (beside this file) holds the workflow and every rule both harnesses
follow; this file holds what only a Codex main loop needs. Read it before
announcing, and apply the model gate and the permissions check first.

## Model gate

The main loop must be GPT-6 Astra. Any other model fails the gate: say so and
skip the workflow. (SKILL.md says why the gate exists: Phases 3 and 5 put
review and triage on this loop. The builders run on `CODEX_BUILDER_MODEL`,
read through `bin/roster-get`; see Doctor and roster paths.)

You cannot see your own model slug. Astra and the builders' model share a base
prompt, and `-m`, `--profile`, `-c` and `/model` all override `config.toml`, so
no file you can read settles it. Unless the user named your model in this
session, ask before announcing anything; that ask is the first approval gate
below.

## Launch and permissions

Run the main loop with `--sandbox workspace-write --ask-for-approval
on-request`. Workers inherit the main loop's sandbox, and Codex cannot give a
worker a narrower one, so scout and researcher are read-only by their
instructions only, not by the sandbox. Shell network is off by default under
workspace-write.

Read the permissions text Codex gave you, before announcing:

- A sandbox is active and escalation is impossible (approval policy `never`,
  or a granular policy with sandbox approvals off): commits, the lane wrappers
  and possibly the combo-log emit all need escalation. Say so to the user and
  stop; do not begin Phase 1.
- Full access, no sandbox: proceed, since nothing needs escalation. Announce at
  activation that workers can write anywhere and that scout and researcher are
  read-only by instruction only.
- Any other sandbox with escalation possible: tell the user before
  dispatching that every worker runs in it.

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
(`delegate-builder`, `scout` or `researcher`), `message` is the order, and
`fork_turns` is `"none"` always (the default forks this loop's whole history
into the worker). `task_name` is unique per order: non-empty, only lowercase
letters, digits and underscores (`a-z`, `0-9`, `_`), `root` is reserved, and a
name is never reused within the session (`build_1`, `fix1_1`, `fix2_1`).

Never spawn the built-in `default`, `worker` or `explorer` roles, and never
omit `agent_type` (it falls back to `default`): they run unpinned on this
loop's own model. This is the Codex form of the Claude Code side's no-fork,
no-general-purpose rule.

The multi-agent tools are `spawn_agent`, `send_message`, `followup_task`,
`wait_agent`, `interrupt_agent` and `list_agents`. There is no close tool: a
finished or errored worker is unloaded automatically when a new spawn needs
its slot. Codex's default limit is 4 agents including this main loop, so at
most 3 workers at once; Codex's own prompt states the count, and if it
differs, follow it. Independent orders spawn in the same turn, up to that
limit. On an agent-limit error, wait for a finisher, then retry the spawn.

`wait_agent` returns on the FIRST finisher and also on timeout: a timeout is
not a report, so keep waiting until every spawned worker has delivered its
final message. A worker that ends without one is a Phase 3 finding.

SKILL.md's cycle-two "one narrow correction to the same builder" goes through
`followup_task` to that worker's `task_name`.

Codex spawns only when explicitly told to: this skill is that instruction, so
never do an order's work inline beyond SKILL.md's under-10-minute rule.

Workers load `~/.codex/AGENTS.md` (AGENT_BEHAVIOR.md), so orders never
restate it. Worker hooks fire SubagentStart/SubagentStop, not
SessionStart/Stop, so workers get no Director digest: an order that depends on
a Director decision states it.

## Approval gates

Codex proceeds unless a skill explicitly requires approval, so only the points
where SKILL.md waits on the user are gates here. At each one of these, stop and
wait for the user's answer before going on:

- The model confirmation (see Model gate) requires approval: stop and wait for
  the user.
- Resolving ambiguity in Phase 1 requires approval: stop and wait for the user.
- A step 4 finding that needs a user decision requires approval: stop and wait
  for the user.
- The Claude lane opt-in requires approval: stop and wait for the user; ask
  before any use of it, since it bills Anthropic tokens.
- srt missing for the Kimi lane requires approval: report it, then stop and
  wait for the user to decide.

Everything else SKILL.md asks for is an announcement, not a gate. Skipping
Phase 4 (name what makes the change low-stakes), dropping an installed lane,
and in Phase 5 deferring a new finding that is neither a regression nor
blocking (deferred by default unless the user says otherwise) all follow
SKILL.md's own semantics: you announce, the user can veto, and you do not stop
and wait. The announcement is mandatory before you proceed, every time; it is
the user's chance to veto, and a veto in chat is honored.

## Escalation

Escalation approval is Codex's own approval prompt, never a chat pre-ask: do
not message the user to ask before an escalated command. Call it with
`sandbox_permissions: "require_escalated"` and a justification, and the prompt
is the ask. Never pass `prefix_rule`: approving one with "always" writes a
standing allow rule into `~/.codex/rules`. Never add rules or edit `~/.codex`
config yourself.

If the permissions text says `approvals_reviewer` is `auto_review`, Codex's
auto-reviewer decides each escalation rather than the user. Tell the user so
once, at activation. Commits and the Kimi lane then proceed without the
user's approval prompt; the chat gates above still stop.

A denied escalation is a veto, never something to retry or route around (an
unescalated wrapper only fails with exit 71). A denied lane wrapper skips that
lane: name it with kind "denied" in the roster announcement and log it as
`<lane>:denied` in the combo log.
A denied git write stops the workflow at that point: report it to the user. A
denied combo-log emit: put the record line in the summary for the user to log.

These need escalation:

- The Kimi and Claude lane wrappers. srt cannot start inside Codex's Seatbelt
  sandbox (nested `sandbox-exec` fails with exit 71); outside it, the wrapper
  re-confines itself under srt.
- Every git write (add, commit, branch, `worktree add`), because
  workspace-write keeps each writable root's `.git` read-only unless `.git`
  itself is a configured writable root.
- `director emit` for the combo log, only if the sandbox refuses it.

Workers: their shell commands have no network, but cached web search works in
workers, so a research order can still read the web. A worker may request
escalation itself (network, a write outside the sandbox); the prompt reaches
the user through Codex's approval UI, or the auto-reviewer, labeled by worker.
An order therefore names any escalation it expects up front, and builders
commit only when their order says so.

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
`"$(cd -P ~/.agents/skills/delegate-build/.. && pwd)/bin/doctor"`.
Read the roster only through `bin/roster-get` beside it, never by reading
`roster.conf` yourself.
