---
name: copilot-loop
description: Run GitHub Copilot's PR review in as few billed rounds as possible. Make sure a review lane has read every line of the head Copilot first sees, read each Copilot review whole (inline comments and the overview body), fix each round by class, have the no-cost lanes review the fixes before the next request, and stop at a bound. Use when opening a PR that Copilot will review, or when the user asks to request, check, or handle a Copilot review, or to run the fix-and-re-request loop; a request only to check a review's status gets a report and changes nothing.
---

# copilot-loop: fewer Copilot rounds per PR

Every Copilot review is billed: GitHub charges each one in AI credits, about
$0.25 to $5 at the default Balanced effort, including reviews a push
triggers (https://docs.github.com/en/copilot/concepts/agents/code-review).
In a 2026-10 sample of 45 PRs, Copilot kept finding about one new comment per
round with no decay, and 42% of clean rounds saw a later round find more, so
the goal is fewer rounds, not a silent Copilot. Fix code drove the rounds:
later-round comments landed 4 to 8 times more densely on the previous
round's fix lines, and on the PRs where it could be measured, 8 of 12
round-one comments sat on lines written by fixes made after the lanes ran.
Sources and method: `notes/copilot-review-gap-2026-10.md` in this skill's
repository.

**Lanes.** How to invoke the GPT, Kimi and Claude review lanes, with their
pins and confinement, lives in the delegate-build skill's mechanics file for
your harness: `~/.claude/skills/delegate-build/claude-code.md` in Claude
Code, `~/.agents/skills/delegate-build/codex.md` in Codex, Phase 4 lane list.
In any other harness there is no mechanics file: ask the user which lanes to
run, or skip the lane steps and say so. Every lane request follows
delegate-build's Phase 4 output rules: every finding, no word cap, one entry
each with file:line, severity, defect and failure scenario.

**Severity.** Copilot's review body lists each open issue with a severity
tag and a link to its inline comment. Where a comment has no tag, use the
severity your own triage gives it.

## Status only

When the user only asks whether a review has landed or what it says, read
it (Each round, steps 1 and 3), report, and stop. Request reviews, fix, or
push only when the user asked for the loop.

## Before the first review

1. **A lane has read every line of the head.** A delegate-build run that ran
   Phase 4 and closed Phase 5 leaves the head that way; one that skipped
   Phase 4 or had no lane available does not. Otherwise:
   - a change no lane has seen gets a breadth pass on every installed
     no-cost lane, base the merge base with the PR's target branch, unless
     the user says otherwise;
   - commits after the last lane review get a fix review on them, base the
     last lane-reviewed head (Each round, step 5).
   Triage and fix what those lanes find exactly like a Copilot round (Each
   round, steps 4 and 5) before the first Copilot review.
2. **The PR description holds.** Copilot reads the title and description and
   flags code that contradicts them; no lane has seen them. Put the draft
   description in the last lane request and ask for every claim the code
   contradicts, or check each claim against the head yourself.
3. **Deferred findings are named.** List valid findings deliberately left
   out of the change in the description, under a heading such as "Known, not
   fixed here", each with its reason. The reader sees the call was
   deliberate; whether Copilot then skips them is unverified.
4. **Pushes do not trigger reviews.** Check the rules that apply to the
   target branch: `gh api repos/<owner>/<repo>/rules/branches/<branch>` lists
   them, repository and organization rulesets alike. A `copilot_code_review`
   rule with `review_on_push: true` bills a review on every push, and one
   with `review_draft_pull_requests: true` reviews draft PRs too. If either
   is on, tell the user before pushing; never turn either on. Personal
   settings for automatic review on open cannot be read this way, and that
   review on open is fine.

## Each round

1. **Read what is there first.** List the PR's reviews (`gh api
   repos/<owner>/<repo>/pulls/<n>/reviews`; Copilot's reviewer login is
   `copilot-pull-request-reviewer[bot]`). Count Copilot's reviews for the stop
   rule. If the newest one has not been processed yet (an automatic review on
   open, or one requested earlier), process it from step 3 instead of
   requesting another.
2. **Request and wait.** Apply the stop rule first. Note the time, request
   with `gh pr edit <n> --add-reviewer @copilot` (gh 2.97+), and wait for a
   Copilot review submitted after that time whose `commit_id` is the SHA you
   pushed: key to the pushed SHA, never the PR's reported head, since GitHub
   can lag in syncing a push. Reviews have landed within about five minutes
   (2026-10). If none has landed after 20 minutes, or the new review is on
   another SHA, stop and tell the user; do not wait on or re-request.
3. **Read the whole review**: every inline comment AND the review body. The
   body lists the open issues with their severities, and under "Previously
   missed" any new findings on code that had not changed. GitHub's docs say
   files under its built-in exclusions (`**/bin/**/*` among them, with
   documented exceptions; https://docs.github.com/en/copilot/reference/review-excluded-files)
   are not considered, yet on this repository's PR #25 (2026-10) the body's
   headline described a defect in a `bin/` script while listing no open
   issue, and no inline comment existed. So when the headline names a
   problem no open issue accounts for, find it in the code the headline
   points at; if you cannot place it, report it to the user rather than
   guess.
4. **Triage the round as a whole, fix by class.** For each accepted comment,
   name the defect class, search the lines the change adds or modifies for
   other instances, and fix them all; Copilot otherwise comes back for the
   sibling in a later round (in the sample, one sanitize bypass returned in
   rounds 1, 3 and 4). An instance in code the change does not touch is
   named as a follow-up, not fixed.
5. **Fix review before pushing.** Run every installed no-cost lane on the
   fix range: base the last lane-reviewed head (the SHA Copilot last reviewed,
   when no fix review has run since), head the fixed tree, with the merge
   base named for context. Each request carries the comments or findings the
   fixes address and asks for: a fixed / still-open verdict on each; defects
   in the code the fix wrote or changed, and in callers of what it changed;
   the same defect class elsewhere in the change; and, if the description
   changed, claims the code contradicts. Fix what it finds valid, and give
   that fix its own fix review, base the head the previous one read. At most
   three fix reviews per round: valid findings the third leaves go to the
   user as open before the push, and the user decides.
6. **Push once**, all of the round's fixes batched, then start the next round
   at step 1.

## Stop rule

Stop requesting rounds when either holds:

- the latest review raised nothing you accepted above low severity, inline
  or in the body; or
- three Copilot reviews have run on the PR, an automatic review on open
  included.

Past that, a round runs only when the user asks for it. A clean round does
not prove the PR clean; the stop rule trades the residual findings for cost,
and that trade is the user's to change.

## Record

When the loop ends (merge, stop rule, or the user's call), emit one
`director emit --type note --area copilot-rounds` with `<repo>#<n>:
rounds=<n> inline=<per-round counts, e.g. 3,1,0> body_only=<n> accepted=<n>
rejected=<n> prepared=<delegate-build|breadth|fix-review|none>
stop=<clean|bound|user|merged>`. These notes are how the round count is
measured over time. In Codex the write goes through the escalation path
`codex.md` gives for `director emit`. If `director` is not on PATH or the
write is refused, put the same record at the end of your final message.

## Repository setup (once per repo)

Copilot code review reads repository custom instructions from the PR's head
branch: `.github/copilot-instructions.md`, path-specific
`.github/instructions/*.instructions.md`, and `AGENTS.md`
(https://docs.github.com/en/copilot/tutorials/customize-code-review). A short
section there stating the repo's threat model and what is out of scope cuts
comments that triage rejects anyway: 5 of the 10 rejected comments in the
2026-10 sample were outside the threat model.
