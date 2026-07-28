---
name: audit-directives
description: Audit AGENT_BEHAVIOR.md against the live harness system prompts — fetch fresh Codex/OpenCode prompts, diff them against the committed snapshots, and classify every affected directive as absent, duplicate, or conflict. Use on any Claude Code release or update, on a new Claude model generation, on a Codex CLI version bump, on an OpenCode update, or on demand after editing AGENT_BEHAVIOR.md.
---

# audit-directives — does each directive still earn its keep?

Why this exists: AGENT_BEHAVIOR.md is meant to carry only what the harness
prompts don't already carry. Those prompts change under us. A directive that was
load-bearing last month may now be restated verbatim by the harness (dead weight
in every context window) or contradicted by it (actively harmful — the file's own
routing rule says the harness wins, so a stale directive just loses, loudly).
Neither failure is visible from inside a session. Committed snapshots of the
harness prompts turn that invisible drift into a git diff.

Repo root: `/Users/colin/dev/src/skills`. Run every command from there.

## Step 1 — Fetch

`bin/fetch-harness-prompts` (narrow with `--only codex` or `--only opencode`).
It writes `harness-snapshots/codex/prompt-1.txt…prompt-N.txt` and
`harness-snapshots/opencode/<model>.txt`, each with a `metadata.json`. Codex
ships prompts per model family — audit the file(s) marked `"active": true` in
`codex/metadata.json` (keyed to the model in `~/.codex/config.toml`, listed as
`configured_model`), not prompt-1, which is merely the largest. A model may
carry TWO actives — a base prompt and a personality-template variant differing
by one placeholder; audit both, noting they are near-identical. If metadata
says `"active_source": "heuristic"`, the flag is a marker-based guess (no or
unmatched configured model) — treat the active choice as unverified and say so
in the report. Output carries no timestamps, so a refetch with no upstream
change diffs clean (for OpenCode this holds when metadata's `ref` is a version
tag; a default-branch ref moves on its own).

If the fetch fails, report the failure plainly and continue the audit against
whatever is already committed. A stale snapshot is worth auditing; a skipped
audit is not.

## Step 2 — Detect drift

`git add -N harness-snapshots/ && git diff harness-snapshots/`

(`add -N` makes brand-new files — a first baseline, a prompt file a release
added — show up in the diff; plain `git diff` silently skips untracked files.)

The diff IS the change detector. The audit's scope is the changed files only —
a harness whose files are unchanged has nothing to audit. Read the diff hunks,
not just the file list: what the harness *added* is what can now duplicate or
contradict a directive.

If the user explicitly asked for a full audit, ignore the diff and audit
everything.

## Step 3 — Claude Code (no fetching — this is the point)

No script can retrieve the Claude Code system prompt. It doesn't need to: you are
running inside Claude Code and its system prompt is in your context. Read it
there.

Sanity marker — the live prompt should contain, verbatim:

    Write code that reads like the surrounding code: match its comment density, naming, and idiom.

If that string is **missing**, treat the entire Claude Code prompt as changed
and audit it in full.

Otherwise, snapshot first, then diff — so Claude Code drift becomes a git diff
like any other harness:

- `harness-snapshots/claude-code/system-prompt.txt` — the live system prompt's
  harness prose, verbatim. EXCLUDE: tool/function schemas and the tool-system
  preamble, system-reminder rosters (skills, agent types, MCP instructions),
  the gitStatus session block, and the appended AGENT_BEHAVIOR.md sections
  (`### IDENTITY` / `### CRITICAL BEHAVIOR`) — including those would make the
  audit compare the file against itself. If a sentence contains harness tool
  markup you cannot emit literally, normalize it (e.g. backtick the tag name)
  and record that.
- `harness-snapshots/claude-code/metadata.json` — `{"excludes": [...],
  "model": "<exact model id from the environment>", "normalizations": [...]}`.
  No timestamps.

Now `git diff harness-snapshots/claude-code/` scopes this audit the same way
Step 2 scopes the others — but only if the committed snapshot came from the
same model (check its metadata.json): the prompt varies with model and session
settings, so a cross-model diff is noise, not drift. No committed snapshot yet,
or a different model? This run is the baseline — audit the full prompt.

## Step 4 — Classify

For each changed harness, pull the directives that actually route to it:

| AGENT_BEHAVIOR.md section | Applies to |
| --- | --- |
| `SHARED — all models, all harnesses` | every harness |
| `MODEL: CLAUDE FABLE/MYTHOS`, `MODEL: CLAUDE OPUS` | Claude Code only |
| `HARNESS: OUTSIDE CLAUDE CODE` | Codex, OpenCode (and any other non-Claude-Code harness) |

`IDENTITY` is persona, not a behavioral rule competing with a harness prompt —
out of scope.

Give every such directive one of three verdicts against the harness prompt text:

- **absent** — the harness prompt doesn't cover it. The directive earns its keep. Keep it.
- **duplicate** — the harness prompt now covers it. Redundant; candidate for removal.
- **conflict** — the harness prompt says otherwise. Flag it. The harness wins by
  the file's own routing rule, so the directive needs rewording or removal.

Judge against what the harness prompt actually says, not what you remember it
saying. Every non-absent verdict needs a quote.

A SHARED directive is removable only when it is **duplicate on every harness**
— duplicate on one and absent on another means keep. Per-harness sections need
only their own harness's verdict.

## Step 5 — Report

One table per audited harness: directive → verdict → evidence quote from the
harness prompt.

Then propose concrete AGENT_BEHAVIOR.md edits — and **never apply them without
explicit user approval**. Finish by offering to commit the refreshed snapshots.

## Step 6 — State the limits (always, in the report)

- This catches **textual collision only**, not behavioral drift.
- A clean run means "no contradictions found" — it does **not** mean "these
  directives are good."
- It cannot detect a directive that quietly stopped earning its keep: one the
  model now follows by default, or that never changed behavior at all.
- Behavioral (Tier 2) discrimination needs real runs with and without the
  directive. Out of scope here. Don't imply otherwise.

## Operational notes

- Codex's "Sandbox and approvals" section is injected at runtime from config, not
  baked into the binary. Its absence from a snapshot is expected, not drift.
- Known dead ends — do not re-walk them:
  - WebFetch paraphrases its sources; it will hand you a plausible summary of a
    prompt instead of the prompt. `curl` the raw HTML/text instead.
  - `strings | grep` on the Codex binary.
  - Searching the Homebrew OpenCode bundle for prompt text.
