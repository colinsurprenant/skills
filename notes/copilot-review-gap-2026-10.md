# Why Copilot kept finding issues after our review lanes (2026-10)

Our PRs went through several pre-PR review passes (GPT through Codex, Kimi
through OpenCode, sometimes Claude), and GitHub Copilot's PR review still
found valid issues on them, round after round, each round billed. This note
records what the data showed and what we changed. The numbers back the rules
in [delegate-build](../delegate-build/SKILL.md) Phases 4 and 5 and in
[copilot-loop](../copilot-loop/SKILL.md).

## Sample and method

- Population: 178 PRs opened 2026-09-01 to 2026-10-24 across 7 of the
  author's repositories (3 public, 4 private). 175 had Copilot reviews: 445
  reviews and 522 inline comments.
- Sample: 45 of those PRs and all 278 of their inline comments, weighted
  toward PRs whose session logs show lane reviews (27 had lanes run before
  Copilot's first round, 6 on the same head as that round).
- A model classified every comment from its text plus the author's reply or
  the session's adjudication; it did not re-verify each against the code.
  "Accepted" below means accepted by the author or the session, not
  independently confirmed.
- The per-comment dataset stays private, since it quotes private
  repositories; this note carries its aggregates only.

## What the data showed

**Every reviewer samples.** On the 4 PRs where the logs recorded the overlap
on the same head, the lanes had raised 8 of Copilot's 21 round-one findings
(38%), and the lanes in turn found issues Copilot did not. Copilot does not
agree with itself either: 112 reviews carry a "Previously missed" section
for code that had not changed since its last review.

**Copilot did not converge in this sample.** Rounds per PR: median 2, mean
2.55, maximum 17. Inline comments per round stayed flat, about one per round
from round one to round six and beyond. Of 60 rounds with no inline comment
that were followed by another round, 25 (42%) saw a later round find more.

**Fix code is where later rounds come from.** Of 158 round-two-and-later
comments whose position could be measured, 28% landed on a line the previous
round's fix changed and 37% within three lines of one, while a fix round
changed a median 7% of the PR's added lines.
On the 6 PRs whose logs name the exact head the lanes reviewed, 8 of 12
Copilot round-one comments sat on lines written by fix commits made in
response to the lanes, which no lane had re-reviewed.

**Lane reports were capped.** Lane requests asked for a ranked report under
800 to 900 words, and lanes returned 1 to 9 findings per pass. Copilot's
agents record findings through a tool call as they read (seen in its job
logs), and we saw no cap on their number.

**Smaller causes.** Lane findings deferred in triage came back as Copilot
comments (on one PR, 3 of 5 round-one comments). Only Copilot checked the
code against the PR description (about 4% of comments). A lane was down
during several reviews. A design doc that skipped the lanes as "docs only"
then took 13 Copilot rounds.

**Not the cause: the rubric.** On lane-reviewed heads, 74% of Copilot's
comments were behavior defects the lane rubrics already asked for (edge
cases and error handling 23%, correctness 17%, concurrency and resources
16%, security 13%); prose-type findings (docs contradicting code,
inconsistencies inside the change, stale references) were the other 26%.

**Copilot was usually right.** 96% of adjudicated comments were accepted.
Of the 10 rejected, 5 were outside the repository's threat model.

## Backtest: which lane setup would have caught more (2026-10-25)

12 of the sampled PRs (7 repositories) were replayed at the commit Copilot
first reviewed, each checkout cut off from every later commit. Every setup
was scored against Copilot's 48 round-one inline comments by one judge, who
read the code at that commit; MATCH means the same root defect, specific
enough that fixing it per the finding fixes Copilot's issue.

| Setup | MATCH | Findings per PR | Input tokens |
| --- | --- | --- | --- |
| `gpt-6-astra` high, one pass, ranked, under 900 words (the lane as asked then) | 29% | 3.6 | 1x |
| `gpt-6.1-sol` high, one uncapped pass with a Copilot-style method (mean of 3) | 47% | 6.4 | about 3.5x |
| Three such passes merged | 52% | 9.2 | about 10.8x |
| Three passes merged, low and medium findings kept on 2 of 3 votes | 50% | 6.0 | about 10.8x |

- The merged passes caught 11 comments the capped pass missed, and the
  capped pass caught none they missed; they did at least as well on all 12
  PRs and better on 6.
- The gain was in medium-severity behavior defects (12 of 22 against 5).
  Prose-type comments (stale counts, comment drift) were caught by no setup
  (at most 1 of 12), and on one PR every setup reviewed a large results file
  and skipped the scripts beside it.
- Of 20 sampled findings from the voted setup that matched no Copilot
  comment, 16 were real defects, 4 debatable, none wrong.
- The capped and uncapped setups differ in model, method and cap at once, so
  the test cannot say which of the three matters most.

That is why the GPT lane moved to one uncapped `gpt-6.1-sol` pass and every
lane request carries the method (delegate-build Phase 4), rather than a
three-pass ensemble: one pass gets about 90% of the ensemble's catches at a
third of its cost.

## What Copilot runs (as of 2026-10)

From the code review job logs of this repository's own reviews
(`autofind` 0.1.163): three independent agents on `gpt-6.1-sol` at high
reasoning effort, an aggregation pass on `gpt-6-astra` at medium, cheaper
models for severity, deduplication and grouping, and a vote threshold under
which low and medium severity findings need two of the three agents. A
review from 2026-10-01 in the same repository ran a single `gpt-5.6-sol`
agent instead, so the pipeline changes often. GitHub bills each review in
AI credits, about $0.25 to $5 at the default Balanced effort
([docs](https://docs.github.com/en/copilot/concepts/agents/code-review)),
including reviews a push triggers.

## What changed

- Lane requests ask for every finding, each with a severity, across every
  changed file (`bin/` included, which Copilot excludes by default).
- Every fix cycle ends in a fix review on the lanes, at most three cycles,
  so when the lanes run, no line reaches the PR that no lane has read. Fixes
  are made by class, and valid findings inside the change are fixed rather
  than deferred, up to that bound; what is left at the bound goes to the
  author as open.
- Skipping lane review keys on what a change can break, never its size.
- The copilot-loop skill runs the Copilot rounds themselves: where lanes are
  available, a lane has read every line before the first review, each
  review is read whole, fixes get a fix review before the next request, and
  a stop rule bounds the rounds.
  Automatic review on every push stays off.

The measure of success is fewer Copilot rounds per PR, which copilot-loop
records per PR. Given how Copilot behaved in this sample, we do not expect
any lane to make it go silent.
