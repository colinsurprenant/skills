---
name: copilot-loop
description: Run GitHub Copilot's PR review in as few billed rounds as possible. Make sure a review lane has read every line of the head Copilot first sees, request re-reviews by hand, read each review whole (inline comments and the overview body), fix each round by class, have the no-cost lanes review the fixes before re-requesting, and stop at a bound. Use when opening a PR that Copilot will review, or when the user asks to request, check, or handle a Copilot review, or to run the fix-and-re-request loop.
---

# copilot-loop: fewer Copilot rounds per PR

Every Copilot review is billed: usage-based AI credits since 2026-06-01,
roughly $0.25 to $5 a review at the default Balanced effort, and a review a
push triggers is billed like one requested by hand. Copilot never runs out of
findings. In a 2026-10 sample (45 PRs across 7 repos) it raised about one new
comment per round with no decay, and 42% of clean rounds were followed by a
round that found more. So the goal is fewer rounds, not a silent Copilot.
Two facts shape this procedure: fixes are where later rounds come from (28 to
37% of round-two-and-later comments land on or right beside lines the
previous round's fixes changed), and on the PRs where it could be measured,
8 of 12 round-one comments sat on code written after the review lanes ran.

Lane mechanics (how to invoke the GPT, Kimi and Claude review lanes, their
pins and confinement) live in the delegate-build skill's mechanics file for
your harness: `~/.claude/skills/delegate-build/claude-code.md` in Claude Code,
`~/.agents/skills/delegate-build/codex.md` in Codex, Phase 4 lane list. The
output rules are delegate-build's Phase 4: every finding, no word cap, one
entry each with file:line, severity, defect and failure scenario.

## Before the first review

1. **A lane has read every line of the head.** A delegate-build run ends that
   way (its Phase 5). Otherwise: a change no lane has seen gets a breadth pass
   on every installed no-cost lane first, unless the user says otherwise; a
   change with commits after its last lane review gets a fix review on them
   (below).
2. **The PR description holds.** Copilot reads the title and description and
   flags code that contradicts them; no lane has seen them. Put the draft
   description in the last lane request and ask for every claim the code
   contradicts, or check each claim against the head yourself.
3. **Deferred findings are named.** List valid findings deliberately left out
   of the change in the description, under a heading such as "Known, not
   fixed here", each with its reason. The reader sees the call was deliberate;
   whether Copilot then skips them is unverified.
4. **No review on push.** Never turn on Copilot's "Review new pushes" (the
   `review_on_push` parameter of a ruleset's `copilot_code_review` rule) or
   review of drafts: each push would bill a review. Copilot's automatic review
   when a PR opens is fine.

## Each round

1. **Request and wait.** Re-request with `gh pr edit <n> --add-reviewer
   @copilot` (gh 2.97+). Watch for the review whose `commit_id` is the SHA you
   pushed, never the PR's reported head: GitHub can lag in syncing a push.
2. **Read the whole review**: every inline comment AND the review body. The
   body carries findings Copilot does not post inline. Files under its
   built-in exclusions (`**/bin/**/*` among them, except Rust files; list at
   https://docs.github.com/en/copilot/reference/review-excluded-files) get no
   inline comment: a finding there shows only as the overview headline, for
   example "Changes recommended" with "No open issues" (skills PR #25). The
   body also lists findings on unchanged code under "Previously missed", and
   tags each with a severity.
3. **Triage the round as a whole, fix by class.** For each accepted comment,
   name the defect class, search the change for other instances, and fix them
   all; Copilot otherwise comes back for the sibling next round (one sanitize
   bypass returned in rounds 1, 3 and 4 of one PR).
4. **Fix review before re-requesting.** Run every installed no-cost lane on
   the round's fix range (the SHA Copilot last reviewed to the new head, with
   the merge base named for context). Each request carries the Copilot
   comments the fixes address and asks for: a fixed / still-open verdict on
   each; defects in the code the fix wrote or changed, and in callers of what
   it changed; the same defect class elsewhere in the change; and, if the
   description changed, claims the code contradicts. Fix what it finds valid;
   that fix gets its own fix review. Then push once, all fixes batched.
5. **Re-request only if the stop rule allows** (step 1).

## Stop rule

Stop requesting rounds when either holds:

- the latest round raised nothing you accepted above low severity, inline or
  in the body; or
- three Copilot reviews have run on the PR (an automatic review on open
  counts).

Past that, a round runs only when the user asks for it. A clean round does
not prove the PR clean; the stop rule trades the residual findings for cost,
and that trade is the user's to change.

## Record

When the loop ends (merge, stop rule, or the user's call), emit one
`director emit --type note --area copilot-rounds` with `<repo>#<n>:
rounds=<n> inline=<per-round counts, e.g. 3,1,0> body_only=<n> accepted=<n>
rejected=<n> prepared=<delegate-build|breadth|fix-review|none>
stop=<clean|bound|user|merged>`. These notes are how the round count is
measured over time. If `director` is not on PATH, put the same record at the
end of your final message.

## Repository setup (once per repo)

Copilot code review reads repository custom instructions from the PR's head
branch: `.github/copilot-instructions.md`, path-specific
`.github/instructions/*.instructions.md`, and `AGENTS.md`
(https://docs.github.com/en/copilot/tutorials/customize-code-review). A short
section there stating the repo's threat model and what is out of scope cuts
comments that triage rejects anyway: 5 of the 10 rejected comments in the
2026-10 sample were outside the threat model.
