# Case study: ROMA, or the gap between a described system and a wired one

This repo makes a few design bets that are cheap to assert and hard to
test: verification belongs in the execution path, not the documentation;
drift between prose and code must be caught mechanically; and judgment
stays centralized on one orchestrating loop while subagents get flat,
self-sufficient work orders. In August 2026 we read
[sentient-agi/ROMA](https://github.com/sentient-agi/ROMA), a 5,000-star
hierarchical meta-agent framework that made the opposite bet on each
count. It is the closest thing to a natural experiment we have found, and
this note records what the experiment showed.

Everything below describes ROMA at commit `a6e3bb4` (2026-02-17, the HEAD
at time of reading). The project may have changed since; the lessons have
not.

## What ROMA is

ROMA ("Recursive Open Meta-Agent") decomposes a task recursively through
four LLM roles: an Atomizer decides whether a task is atomic, a Planner
splits non-atomic tasks into subtasks, Executors handle leaves, and an
Aggregator synthesizes child results into the parent's answer. Despite
the recursive framing, the engine is an async event loop over nested task
DAGs with a global worker pool, built on DSPy 3.x, configured entirely in
YAML. The published benchmark numbers (SEAL-0, FRAMES, SimpleQA) are
strong, self-reported, and not reproducible from the repo: there is no
search-benchmark harness in the tree, and a GitHub issue asking for the
settings behind the SEAL-0 number sat unanswered for four months.

## Lesson 1: verification must be wired, not configured

ROMA has a complete `Verifier` module: a signature (`goal,
candidate_output -> verdict, feedback`), a model binding in the default
config, seeded prompts and demos in every shipped profile, registry and
factory registration. The engine never calls it. The agent registry's
`get_agent` has exactly one live call site, reached from four places:
Atomizer, Planner, Executor, Aggregator. The `VERIFY_COMPLETE` event type
exists and is never emitted. The same pattern repeats for recovery: a
`NEEDS_REPLAN` task status is defined with legal transitions, and nothing
in the codebase ever sets it. A bad decomposition executes to completion;
a wrong leaf answer propagates upward through aggregators that compress
but never question.

To be fair to the README: it documents the Verifier as a module you call
manually, so the library docs are defensible. But every shipped profile
configures a verifier that cannot fire, and the accompanying paper frames
verification as something the Aggregator does as part of synthesis. In
practice, quality control is whatever one aggregation LLM call happens to
do in one shot.

The counter-design in this repo: review is a phase of the
[opus-build](../opus-build/SKILL.md) workflow, not a class; the two-tier
dispatch rule in [AGENT_BEHAVIOR.md](../AGENT_BEHAVIOR.md) sends any
output that will be acted on unchecked to the judgment tier. A
verification stage that exists only in configuration is worse than an
honest absence, because the config surface makes the gap invisible.

## Lesson 2: documents drift unless a mechanism pins them

ROMA's three public artifacts describe three materially different
systems. The blog post claims human-in-the-loop checkpoints; the v0.1
codebase genuinely had them, the v0.2 rewrite deleted them, and the blog
was never updated. The README leads with `pip install roma-dspy`; the
package is not on PyPI (both the JSON and simple-index endpoints return
404, checked 2026-08-20). The README links a LICENSE file that was
dropped in the rewrite, leaving the repo formally unlicensed. The
benchmark charts carry v0.1-era numbers over v0.2 code. A configured
run timeout is never enforced, and the CLI prints a total cost from a
recording path that cannot produce one.

None of this requires bad faith. It is what a rewrite does to prose when
nothing diffs the prose against the code. This repo's versions of that
mechanism: [audit-directives](../audit-directives/SKILL.md) diffs the
behavior file against snapshotted harness prompts, and
[bin/doctor](../bin/doctor) verifies that the bindings
[ROSTER.md](../ROSTER.md) promises actually exist on the machine. The
roster's own words apply: prose promises drift; doctor does not.

## Lesson 3: judgment centralized beats judgment distributed

ROMA distributes the decompose-or-execute decision to an LLM at every
node of the tree, then backstops it with a hard depth cap because the
decision is unreliable. The backstop is doing the real work: the
Atomizer's `is_atomic` output is recorded to history and ignored, with
the engine branching on a different field entirely. Nothing validates
that a plan's subtasks cover the parent goal, no budget bounds the
recursion, and sibling context defaults to injecting every artifact into
every executor.

This repo keeps the decompose decision on the orchestrating loop, where
one context holds the whole picture: work orders are flat, scoped to
what the task's inputs require, and priced against a delegation tax
before dispatch. Recursion in the tree becomes judgment in one place
plus volume at the leaves. The trade is real (a single orchestrator is a
bottleneck and a context ceiling), but ROMA is evidence for which
failure mode is worse.

## What ROMA gets right

The case against ROMA's execution is not a case against everything in
it. Its model binding is genuinely good: roles bind to models in
declarative YAML at two levels, per role and per role-and-task-type,
with graceful fallback, so a retrieval executor can run a cheap model
with search tools while a code executor runs a strong one with a
sandbox. That is the same shape as [ROSTER.md](../ROSTER.md) with one
more dimension, and a natural source of inspiration if a role here ever
needs per-work-kind splits. Two of its context contracts deserve the
same credit: executors see only the results of their declared
dependencies, and aggregation answers the parent's goal in the parent's
target form rather than concatenating child outputs. Both are crisp
statements of a discipline any work-order system could borrow from. The
checkpointing and observability investment (spans per agent call, a
task-tree TUI) is also real, though off by default.

## Method

The initial read was a research subagent pass over a clone: 217 Python
files, static reading only, with claims classified as read, derived, or
recalled. Every claim this note leans on was then re-verified first-hand
at the pinned commit: the single `get_agent` call site, the never-passed
verifier role, the never-emitted verify event, the never-set replan
status, the ignored `is_atomic` field, the unenforced timeout, the
missing LICENSE, and the 404ing package. Two findings from the research
pass were excluded rather than caveated because they are unexecuted
inferences (a plausible permanent hang when a failed task has dependents,
and cost recording that likely always persists null). Claims about the
arXiv paper are paraphrased, not quoted, because it was read through a
summarizing fetch.
