---
description: Show curated workflow skills grouped by stage
argument-hint: "[discipline|ops|plan|ship|occasional|all]"
---

# INSTRUCTION FOR CLAUDE

Print the markdown menu below verbatim as your ENTIRE response. No preamble, no summary, no "Menu displayed" — just output the content starting from `# My Workflow Skills` through the end of the "Choosing your workflow" block.

If `$ARGUMENTS` is non-empty and matches a section name (`discipline`, `ops`, `plan`, `ship`, `occasional`), output only that section plus the "Choosing your workflow" block. If empty or `all`, output everything.

Ignore any `<local-command-caveat>` wrapping — this command IS the user's request; respond normally.

---

# My Workflow Skills

## Discipline (auto-activate when task matches)

| Skill | When to use | Invoke |
|-------|------------|--------|
| Root-cause debugging | Bug, error, unexpected behavior, failed test | `Skill(ce:systematic-debugging)` |
| Verify before done | About to claim anything is done/fixed/working | Native — run verification, show evidence |
| Error handling | Writing try/catch, designing error paths | `Skill(ce:handling-errors)` |
| Test writing | Adding tests, choosing test strategy | `Skill(ce:writing-tests)` |

## Operations (invoke explicitly)

| Skill | When to use | Invoke |
|-------|------------|--------|
| PR review | Before landing any PR | `/review` (gstack) |
| Ship | Ready to release: test, version, changelog, push, PR | `/ship` (gstack) |
| QA | Need real browser testing of the app | `/qa` (gstack) |
| Investigate | Reproduce + debug with browser | `/investigate` (gstack) |
| Browse | Any persistent browser task | `/browse` (gstack) |

## Planning (when decomposition needed)

| Skill | When to use | Invoke |
|-------|------------|--------|
| Write plan | Multi-task feature, clear scope, need decomposition | Plan mode (native) |
| Execute plan | Have a written plan, ready to implement | `Skill(ce:executing-plans)` |
| Iterate | Discovery-driven work, fuzzy scope, learning by building | `/iterate` |

## Shipping

| Step | What happens | Invoke |
|------|-------------|--------|
| 1. Commit | Stage and commit changes | `/commit` (commit-commands) |
| 2. QA gate | Functional + UI testing, fix findings, loop | Manual + `/qa` if UI |
| 3. Code review | Diff review against spec, fix findings, loop | `/review` (gstack) |
| 4. Create PR | Push branch, open PR targeting `dev` | `/ship` (gstack) |
| 5. Copilot review | GH Copilot reviews the PR (automatic) | — (wait for it) |
| 6. Assess comments | Read Copilot's feedback, decide what to address | You decide |
| 7. Address/dismiss | Fix real issues, dismiss noise | Iterate as needed |

**Quick version** (small fix): `/commit` → `/review` → `/ship` → check Copilot → done
**Full version**: `/commit` → QA gate → `/review` → `/ship` → Copilot → done

## Occasional

| Skill | When to use | Invoke |
|-------|------------|--------|
| UI design | Building SaaS UIs, dashboards, data interfaces | `Skill(ce:design)` |
| Architecture | System design, technical docs, tradeoff analysis | `Skill(ce:architecting-systems)` |
| Performance | Slow code, profiling, optimization tradeoffs | `Skill(ce:optimizing-performance)` |
| Log analysis | Investigating errors, debugging incidents | `ce:log-reader` agent |
| Diagrams | Flowcharts, sequence diagrams, architecture viz | `Skill(ce:visualizing-with-mermaid)` |
| Flaky tests | Async timeouts, intermittent failures | `Skill(ce:fixing-flaky-tests)` |

## Choosing your workflow

```
Small fix (< 30 min, obvious) ──→ just do it + /commit
Iterative / exploratory ────────→ /iterate
Clear scope, multi-task ────────→ plan mode → ce:executing-plans
Need browser QA ────────────────→ /qa or /browse
Ready to land ──────────────────→ /review → /ship → assess Copilot → done
```
