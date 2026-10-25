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

## What the data showed

**Every reviewer samples.** On the 4 PRs where the logs recorded the overlap
on the same head, the lanes had raised 8 of Copilot's 21 round-one findings
(38%), and the lanes in turn found issues Copilot did not. Copilot does not
agree with itself either: 112 reviews carry a "Previously missed" section
for code that had not changed since its last review.

**Copilot does not converge.** Rounds per PR: median 2, mean 2.55, maximum
17. Inline comments per round stay flat, about one per round from round one
to round six and beyond. Of 60 rounds with no inline comment that were
followed by another round, 25 (42%) saw a later round find more.

**Fix code is where later rounds come from.** Of 158 round-two-and-later
comments whose position could be measured, 28% landed on a line the previous
round's fix changed and 37% within three lines of one, while a fix round
changed a median 7% of the PR's added lines: a 4 to 8 times concentration.
On the 6 PRs whose logs name the exact head the lanes reviewed, 8 of 12
Copilot round-one comments sat on lines written by fix commits made in
response to the lanes, which no lane had re-reviewed.

**Lane reports were capped.** Lane requests asked for a ranked report under
800 to 900 words, and lanes returned 1 to 9 findings per pass. Copilot
records each finding as it reads, with no cap.

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
  so no line reaches the PR that no lane has read. Fixes are made by class,
  and valid findings inside the change are fixed rather than deferred.
- Skipping lane review keys on what a change can break, never its size.
- The copilot-loop skill runs the Copilot rounds themselves: a lane has read
  every line before the first review, each review is read whole, fixes get
  a fix review before the next request, and a stop rule bounds the rounds.
  Automatic review on every push stays off.

The measure of success is fewer Copilot rounds per PR, which copilot-loop
records per PR. No lane will make Copilot go silent.
