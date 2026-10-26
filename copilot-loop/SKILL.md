---
name: copilot-loop
description: Run GitHub Copilot's PR review in as few billed rounds as possible. Where review lanes are available, make sure one has read every line of the head Copilot first sees, read each Copilot review whole (inline comments and the overview body), fix each round by class, have the no-cost lanes review the fixes before the next request, and stop at a bound. Use when opening a PR that Copilot will review, or when the user asks to request, check, or handle a Copilot review, or to run the fix-and-re-request loop; a request only to check a review's status gets a report and changes nothing.
---

# copilot-loop: fewer Copilot rounds per PR

Every Copilot review is billed: GitHub charges each one in AI credits, about
$0.25 to $5 at the default Balanced effort, including reviews a push
triggers (https://docs.github.com/en/copilot/concepts/agents/code-review).
In a 2026-10 sample of 45 PRs, Copilot kept raising about one new inline
comment per round with no decay, and of the rounds with no inline comment
that were followed by another round, 42% saw a later round find more. So the
goal is fewer rounds, not a silent Copilot. Fix code drove the rounds: 28% of
later-round comments landed on a line the previous round's fix changed,
while a fix round changed a median 7% of the PR's added lines, and on the PRs
where it could be measured, 8 of 12 round-one comments sat on lines written
by fixes made after the lanes ran. Sources and method:
`notes/copilot-review-gap-2026-10.md` in this skill's repository.

**Lanes.** How to invoke the GPT, Kimi and Claude review lanes, with their
pins and confinement, lives in the delegate-build skill's mechanics file for
your harness: `~/.claude/skills/delegate-build/claude-code.md` in Claude
Code, `~/.agents/skills/delegate-build/codex.md` in Codex, Phase 4 lane list.
In any other harness there is no mechanics file: ask the user which lanes to
run, or skip the lane steps and say so. Every lane request follows
delegate-build's Phase 4 output rules: every finding, no word cap, one entry
each with file:line, severity, defect and failure scenario. A lane reviews
committed SHAs only, so commit before every lane review.

**Severity.** Copilot's review body lists each open issue with a severity
tag and a link to its inline comment. Where a comment has no tag, use the
severity your own triage gives it.

## What the user asked for

- **Status only** ("has Copilot reviewed it?", "what did it say?"): read the
  PR's state (Each round, step 1) and any posted review (step 3), report what
  is posted and whether a review is pending, and stop. Never wait or request.
- **One review**: a single review, without the loop's preparation (say so if
  no lane has read the head). Read the state first and follow step 1's
  rules: report any posted review nobody has processed yet, then wait for a
  pending one (step 2's wait, with its timeout); request (step 2) only when
  neither exists. The user's ask overrides the stop rule. Change nothing.
- **The loop** (fix and re-request until done): everything below. The
  preparation below applies to the loop only.

## Before the first review

1. **A lane has read every line of the head.** A delegate-build run that ran
   Phase 4 and closed Phase 5 leaves the head that way; one that skipped
   Phase 4 or had no lane available does not. Otherwise:
   - a change no lane has seen gets a breadth pass on every installed
     no-cost lane, base the merge base with the PR's target branch, unless
     the user says otherwise;
   - commits after the last lane review get a fix review on them, base the
     last lane-reviewed head (Each round, step 5).
   Triage and fix what those lanes find exactly as in a Copilot round (Each
   round, steps 4 and 5). This preparation is a round of its own for step
   5's budget: at most three lane reviews in all, its first one (breadth
   pass or fix review) included, and step 5's gate applies when the third
   still leaves valid findings. Push the prepared head before the first
   Copilot request, so Copilot reviews what the lanes read.
2. **The PR description holds.** Copilot reads the title and description and
   flags code that contradicts them; no lane has seen them. Put the draft
   description in the last lane request and ask for every claim the code
   contradicts, or check each claim against the head yourself.
3. **Deferred findings are named.** List valid findings deliberately left
   out of the change in the description, under a heading such as "Known, not
   fixed here", each with its reason. The reader sees the call was
   deliberate; whether Copilot then skips them is unverified.
4. **Pushes do not trigger reviews.** Check the rules on the target branch:
   `gh api --paginate repos/<owner>/<repo>/rules/branches/<branch>` lists
   them, repository and organization rulesets alike. A `copilot_code_review`
   rule with `review_on_push: true` bills a review on every push; one with
   `review_draft_pull_requests: true` lets the automatic review run on a
   draft PR too. GitHub's personal Copilot settings offer the same two
   options
   (https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/configure-automatic-review)
   and no API reads them; the ones that apply are the PR author's. Ask the
   author (normally the user) whether "Review new pushes" is on, unless they
   have already said (in this session or in standing instructions); the ask
   is an approval gate, so in Codex end the turn with the question. If
   review on push is on anywhere, or step 1 later finds a Copilot review on a
   push that nobody requested (the automatic review when the PR opens does
   not count), the stop rule cannot hold: tell the user and wait for their
   call before pushing, again an approval gate. Never turn either option
   on. Automatic review when a PR opens is fine.

## Each round

1. **Read the PR's state**: whether it is open (`gh pr view <n> --json
   state`; merged or closed ends the loop), Copilot's posted reviews (`gh api
   --paginate repos/<owner>/<repo>/pulls/<n>/reviews`, reviewer
   `copilot-pull-request-reviewer[bot]`; their count feeds the stop rule),
   and whether one is pending (`gh api
   repos/<owner>/<repo>/pulls/<n>/requested_reviewers` lists Copilot under
   `.users[]` as login `Copilot` until its review posts). These are separate
   calls, and a review can post between them, so re-read all three right
   before any decision that depends on them and after every wait, the
   pending requests before the posted reviews (a review that posts in
   between then shows up as posted rather than vanishing). The rules:
   - Never request a review while one is pending or a posted one has not
     been processed.
   - Process every posted review not processed yet together, as one round
     (steps 3 to 5).
   - Push (step 6) only with no review pending: wait for a pending one first
     (step 2's wait) and fold its findings into the round.
   - With nothing pending or unprocessed, apply the stop rule; it decides
     whether step 2 runs.
2. **Request and wait.** Request with `gh pr edit <n> --add-reviewer
   @copilot` (gh 2.97+), then wait until Copilot no longer shows as pending
   (re-read the listings as step 1 says) and take the review that posted. It
   should be on the SHA you pushed; GitHub can lag in
   syncing a push, so a review can land on the previous head instead.
   Process such a review anyway (it is billed, and its findings may still
   apply), and tell the user the pushed head is not yet reviewed. On this
   repository's PR #25 (2026-10) each review landed within eight minutes of
   its request. If none has posted after 20 minutes, stop and tell the user
   what is committed and not yet pushed; the user decides what happens next.
3. **Read the whole review**: every inline comment (`gh api --paginate
   repos/<owner>/<repo>/pulls/<n>/comments`, those whose
   `pull_request_review_id` is the review's id) AND the review body. The
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
   name the defect class and fix every instance the change is responsible
   for: in the lines it adds or modifies, and in code whose behavior it
   alters (a caller of a contract it changed, a reader of a format it
   changed). Copilot otherwise comes back for the sibling in a later round
   (in the sample, one sanitize bypass returned in rounds 1, 3 and 4). An
   instance the change neither touches nor affects is pre-existing: name it
   as a follow-up, not fixed.
5. **Fix review before pushing.** Commit the fixes, then run every installed
   no-cost lane on the fix range: base the last head a lane reviewed, head
   the fix commit, with the merge base named for context. Each request
   carries the comments or findings the fixes address and asks for: a
   fixed / still-open verdict on each; defects in the code the fix wrote or
   changed, and in callers of what it changed; the same defect class
   elsewhere in the change; and, if the description changed, claims the code
   contradicts. Fix what it finds valid, commit, and give that fix its own
   fix review, base the head the previous one read. At most three fix
   reviews per round. If the third still leaves valid findings, stop and ask
   the user whether to fix them (each such fix gets a fix review before it
   ships) or push as is; this is an approval gate, so in Codex end the turn
   with the question. It waits, where delegate-build's fix-cycle bound only
   announces, because it comes before the push and the next billed request;
   delegate-build's ends a run with a summary and pushes nothing.
6. **Push once**, all of the round's fix commits together, once step 1's
   rules allow it, then start the next round at step 1.

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

When the loop ends (merge, close, stop rule, timeout, or the user's call),
emit one `director emit --type note --area copilot-rounds` with `<repo>#<n>:
rounds=<n> inline=<inline comments per Copilot review, oldest first, e.g.
3,1,0> body_only=<n> accepted=<n>
rejected=<n> prepared=<delegate-build|breadth|fix-review|none>
stop=<clean|bound|user|merged|closed|timeout> pending=<0|1>`, where `rounds`
counts every Copilot review the PR had received when the loop ended, one
that landed on an older head included, and `pending=1` says a requested
review had not posted yet. These notes are how the round count is measured
over time. In Codex the write goes through the escalation path `codex.md`
gives for `director emit`. If `director` is not on PATH or the write is
refused, put the same record at the end of your final message.

## Repository setup (once per repo)

Copilot code review reads repository custom instructions from the PR's head
branch: `.github/copilot-instructions.md`, path-specific
`.github/instructions/*.instructions.md`, and `AGENTS.md`
(https://docs.github.com/en/copilot/tutorials/customize-code-review). A short
section there stating the repo's threat model and what is out of scope cuts
comments that triage rejects anyway: 5 of the 10 rejected comments in the
2026-10 sample were outside the threat model.
