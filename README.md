# skills

My personal coding-agent configuration: Claude Code first, plus Codex CLI
and OpenCode. The wiring is deliberately simple: a dozen symlinks, created
by [bin/install](bin/install) and documented in [SETUP.md](SETUP.md), no
hardcoded paths. The persona is mine: fork and edit.

## Quick start

    git clone https://github.com/colinsurprenant/skills
    cd skills
    bin/install

To update later: `git pull`, then `bin/install` again. Pulled edits to
skills and agents land live through the symlinks; the rerun exists only to
create links a pull introduced, is a no-op otherwise, and ends with the
doctor report either way.

## What's here

Three layers: a behavior contract every harness loads, a build workflow
that decides where work runs, and a little cockpit trim.

### Behavior: one contract, every harness

The same behavior file reaches Claude Code, Codex CLI, and OpenCode, and a
directive only stays if the harness running it doesn't already enforce it.
Keeping that true takes machinery: harness system prompts change under you,
so they're snapshotted, diffed, and the file is audited against them.

- **[AGENT_BEHAVIOR.md](AGENT_BEHAVIOR.md)**: the behavior file. A routing
  header keys its sections to the harness and model actually running: a
  SHARED core everywhere, model sections for Claude Code, a minimal section
  for harnesses whose own prompts cover less.
- **[CLAUDE.global.md](CLAUDE.global.md)**: the `~/.claude/CLAUDE.md`
  target. It carries the `@`-import that delivers the behavior file to
  Claude Code, plus a placeholder for durable preferences. Codex and
  OpenCode consume the file via `AGENTS.md` symlinks.
- **[audit-directives/](audit-directives/SKILL.md)**: the audit skill. It
  snapshots live harness prompts, diffs them against the committed copies,
  and classifies every directive as absent, duplicate, or conflict, so
  directives that stop earning their keep get removed instead of rotting.
- **[harness-snapshots/](harness-snapshots/README.md)**: the committed
  prompt corpus those audits diff against, with provenance and upstream
  licenses in its README.
- **[bin/fetch-harness-prompts](bin/fetch-harness-prompts)**: deterministic
  snapshot fetcher; a refetch with no upstream change leaves the tree
  byte-identical.

### Build workflow: judgment and volume where they belong

Pro/Max plans share one usage pool and models differ in strengths, so the
build loop is split: judgment (planning, review) stays on the strongest
model, implementation volume goes to Opus, and breadth review runs on
external harnesses, under OS-level confinement (see Sandboxing).

- **[opus-build/](opus-build/SKILL.md)**: the split build workflow. Plan and
  review on the main loop, build on fresh Opus subagents at xhigh effort,
  breadth-review on whichever external lanes are installed (Codex, Kimi K3, a
  sandboxed Opus). On a Fable main loop the split is about budget; on an Opus
  main loop it is about context, and the skill states which mode it is in.
  [review-2026-07-27.md](opus-build/review-2026-07-27.md) is the
  adversarial review from its first validation run;
  [sandbox/](opus-build/sandbox/) confines the headless review lanes.
- **[agents/opus-builder.md](agents/opus-builder.md)** and
  **[agents/opus-reviewer.md](agents/opus-reviewer.md)**: the pinned-model
  build and review agents it dispatches to.
- **[commands/iterate.md](commands/iterate.md)**: the discovery-driven loop
  for fuzzy-scope work (frame, build, evaluate, decide). Its premise: in
  discovery work the spec is an output, written at convergence rather than
  guessed up front.

### Trim

- **[trim/statusline.js](trim/statusline.js)**: status line script.
- **[trim/statusline.test.sh](trim/statusline.test.sh)**: renders the status
  line against crafted payloads and asserts the colour band. Run it directly;
  `STATUSLINE=/path/to/other.js` points it at another build for comparison.

## Sandboxing

Agents here run under OS-level confinement (macOS Seatbelt), scoped by trust
and supervision rather than model goodwill:

- The opus-build **K3 reviewer**, an open-weight model running headless
  through OpenCode (which has no OS sandbox of its own), is wrapped in
  Anthropic's [`@anthropic-ai/sandbox-runtime`](https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime)
  by [opus-build/sandbox/k3-review.sh](opus-build/sandbox/k3-review.sh):
  repo readable but not writable, writes confined to OpenCode's own state
  dirs and temp space, network confined to the Kimi API. Fails closed when
  srt is missing rather than degrading to an unsandboxed run.
- The **Codex reviewer** is OS-sandboxed read-only by its plugin's own
  default, pinned in the opus-build skill so a plugin update that widens
  that default gets surfaced, not silently absorbed.
- The **Opus reviewer** gets the same treatment by
  [opus-build/sandbox/opus-review.sh](opus-build/sandbox/opus-review.sh),
  which is the standard Phase 4 Opus path. Sandboxing a reviewer while build
  subagents write files unsandboxed sounds inconsistent, but it is just least
  privilege: builders need write access to do the job and reviewers never do.
- **Everything else**, the main loop and Opus build subagents included, runs
  with Claude Code's own permission prompts. Its native Bash sandbox is
  available and documented in [SETUP.md](SETUP.md), but it is opt-in and off
  in my settings: it trades prompts for a boundary, which pays off only when
  your work mostly stays inside one.

The premise: a git worktree is merge hygiene, not a security boundary. Any
agent that runs `npm install` or a test suite executes third-party code with
your whole account. So the boundary is mechanical wherever a lane runs
headless or on a model without Claude's safety training; permission prompts
only govern sessions a human is actually watching. Where a sandbox is on it
is also an enabler and not only a shield: inside the boundary, commands
auto-run without permission friction.

## Case studies

The design bets above are cheap to assert and hard to test, so when a
project ships the opposite bets at scale, the evidence is worth keeping.

- **[notes/roma-case-study.md](notes/roma-case-study.md)**: Sentient's
  ROMA framework, read against three choices this repo treats as
  load-bearing: verification wired into the path rather than
  configured beside it, mechanical drift audits over prose promises, and
  judgment centralized on one loop rather than distributed through a
  recursive tree. ROMA shipped the opposite of each; the note records
  what that looks like, and credits the ideas of theirs that could
  inspire improvements here.

## Wiring

See [SETUP.md](SETUP.md): everything is symlinks from harness config
directories into this clone. Only Claude Code and those symlinks are
required; every other tool here is optional and retires just the lane that
needs it. [bin/doctor](bin/doctor) reports what is installed and which lanes
that leaves live, which is also the fastest way to see what a partial install
gets you before committing to one.

## Forking

Forking is the distribution model, not a fallback. `bin/install` wires a
clone and `bin/doctor` referees it, but this is not a package: there are no
releases and no compatibility promises, and the parts that make it work
(the persona, ROSTER.md, the preferences in CLAUDE.global.md) are yours to
own from the first day. Install the machinery, fork the identity.

The identity deserves its own word. The `### IDENTITY` section of
AGENT_BEHAVIOR.md gives the agent a working persona (R. Daneel Olivaw,
adapted from Bill Burdick's
[zot/humble-master](https://github.com/zot/humble-master), MIT) and frames
the collaboration as a partnership. It is a deliberate personal choice, not
machinery: nothing else in the repo depends on it, the routing header and
every skill work with any persona or none, and it is the first thing to
rewrite in a fork. Keep the structure, replace the voice.

The transferable ideas are the routing header, the audit skill, the
budget-split workflow, and the roster-verified bindings.

## License

MIT ([LICENSE](LICENSE)). `harness-snapshots/` contains third-party prompt
text redistributed under upstream licenses; see
[its README](harness-snapshots/README.md).
