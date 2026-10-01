# Setup

This repo is a menu, not a bundle. Claude Code plus a handful of symlinks is
the whole required install; everything else (Codex, OpenCode, Kimi,
sandboxing, the status line) is optional and independent. A tool you don't
have retires the one lane that needs it and changes nothing else.

Platform note: the sandboxed review lanes use macOS Seatbelt through
Anthropic's sandbox runtime, so those are macOS only. Every other part of the
repo is platform independent.

## Clone

Everything is delivered by symlinks from harness config directories into this
repo. Clone it anywhere; the links below are location-independent (the
CLAUDE.md `@`-import is relative and resolves through the symlink's real
path):

    git clone https://github.com/colinsurprenant/skills
    REPO="$PWD/skills"    # or wherever you cloned it

## Install

    bin/install            # required Claude Code links, then doctor
    bin/install --all      # plus the Codex (links and agent files), OpenCode, and Copilot CLI setup
    bin/install --copilot  # or any subset: --codex, --opencode, --copilot

Idempotent and non-clobbering: a link already resolving to its documented
target is left alone, and anything else found at a target path, a stray
file or a link to the wrong place, is reported and kept, never replaced. The manual sections below are the same links spelled out,
kept for transparency and for partial installs.

Exit status: a link that cannot be created (for example a parent directory that
cannot be made) is a failure row and exits non-zero. A refused link, one whose
path is occupied by something else, keeps today's semantics for the always-on
Claude Code set (the doctor report's required rows judge it), but under an
explicitly requested flag (`--codex`, `--opencode`, `--copilot`, `--all`) it
exits non-zero as well.

`--codex` does more than link: besides the `AGENTS.md` link it links
`delegate-build` into `~/.agents/skills` and renders three Codex agent files
(`delegate-builder.toml`, `scout.toml`, `researcher.toml`, pinned from the
`CODEX_*` keys in `roster.conf`) into `~/.codex/agents` as regular files, since
Codex refuses symlinked agent files. That skill link is what marks the agent
files as this clone's: if it is refused or cannot be created, `--codex` renders
no agent files and exits non-zero. A plain `bin/install` only refreshes the
agent files it generated earlier, and only when
`~/.agents/skills/delegate-build` links into the clone it runs from. If
generated files exist but that link is missing or points at another clone, it
prints one "not refreshed" row, touches nothing and does not fail; if none
exist it says nothing. It never creates Codex files or the `~/.agents` link.

## Update

    git pull
    bin/install

Content updates need only the pull: skill and agent bodies resolve through
the symlinks at invocation time, so pulled edits are live immediately (only
the name and description listings snapshot at session start). The exception
is the Codex agent files: they are generated copies, so a pulled change to an
agent body or a `CODEX_*` pin reaches Codex on the next `bin/install`, which
refreshes the ones it generated earlier (when `~/.agents/skills/delegate-build`
links into this clone; see Install). Rerunning `bin/install` also covers a
pull that introduces a new link; with no Codex agent files to refresh it is a
no-op otherwise, and it ends with the doctor report.

The build skill and its agents were renamed to model-agnostic names
(`opus-build` is now `delegate-build`, `opus-builder` is `delegate-builder`,
`opus-reviewer` is `claude-reviewer`, and a `scout` agent was added). After a
pull that crosses the rename, `bin/install` removes each old link that still
names its old target in this clone, silently leaves anything else at those
paths alone, and creates the new ones. If you linked by hand, remove the old three
yourself:

    rm ~/.claude/skills/opus-build ~/.claude/agents/opus-builder.md ~/.claude/agents/opus-reviewer.md

## Check what you have

    bin/doctor

Reports which tools are installed, which symlinks resolve into this clone, and
which delegate-build review lanes are live. Run it again after any step below.
Its optional Codex rows cover the `~/.agents/skills/delegate-build` link and
each generated agent file, checked whole against `roster.conf` and the
`agents/*.md` bodies (drift names `bin/install --codex` as the fix). With
`codex` on PATH and neither that link nor any generated file, they collapse to
one row saying delegate-build is not installed for Codex; without `codex` on
PATH, the link row stays and the agent-file rows give way to one row saying
Codex is not installed.
`bin/doctor --deep` additionally verifies the OpenCode model slug, which needs
network. Unmet optional checks are informational: they tell you which lane is
retired, not that something is broken. The exit status scores only the
required checks, so a Claude-only install exits 0.

## Required: Claude Code

    mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/commands
    ln -s "$REPO/CLAUDE.global.md"            ~/.claude/CLAUDE.md
    ln -s "$REPO/audit-directives"            ~/.claude/skills/audit-directives
    ln -s "$REPO/delegate-build"              ~/.claude/skills/delegate-build
    ln -s "$REPO/agents/delegate-builder.md"  ~/.claude/agents/delegate-builder.md
    ln -s "$REPO/agents/claude-reviewer.md"   ~/.claude/agents/claude-reviewer.md
    ln -s "$REPO/agents/researcher.md"        ~/.claude/agents/researcher.md
    ln -s "$REPO/agents/scout.md"             ~/.claude/agents/scout.md
    ln -s "$REPO/commands/iterate.md"         ~/.claude/commands/iterate.md

If you already have a `~/.claude/CLAUDE.md`, the first link fails rather than
clobbering it: fold your content into your fork of `CLAUDE.global.md` (it has
a placeholder section for durable preferences), then move the old file away
and link.

`CLAUDE.global.md` `@`-imports `AGENT_BEHAVIOR.md`, which delivers the
behavior file to every session and non-fork subagent, from any entry point.
Skill and agent bodies resolve through the symlinks at invocation time:
edits land live, no session restart needed (only the name/description
listings are snapshotted at session start).

## Optional: Codex CLI, OpenCode, and Copilot CLI

All three consume `AGENT_BEHAVIOR.md` whole: Codex and OpenCode through
their `AGENTS.md` mechanism (neither processes `@`-imports, which is why
the file is self-contained), Copilot CLI through its user-level
`copilot-instructions.md`, loaded in every session regardless of cwd
(verified against Copilot CLI 1.0.80; it does expand relative `@`-imports,
which the file does not use). Link only the ones you use:

    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.codex/AGENTS.md
    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.config/opencode/AGENTS.md
    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.copilot/copilot-instructions.md

Copilot notes: the global file is additive alongside any repo-level
instruction files (Copilot defines no precedence between instruction
sources), and a running session does not pick up changes; they apply from
the next session. To confirm the wiring once, run `/instructions` inside a
session and look for "Home copilot-instructions.md" under the User group.

## Optional: delegate-build on Codex

`bin/install --codex` also makes delegate-build runnable from a Codex main
loop: it links the skill into `~/.agents/skills/delegate-build` and renders
three agent files, `delegate-builder.toml`, `scout.toml` and `researcher.toml`,
into `~/.codex/agents`. They are generated from the `CODEX_*` keys in
`roster.conf` plus the bodies of `agents/*.md`, so the instructions have one
source. Codex refuses symlinked agent files, which is why these are real files,
refreshed by a plain `bin/install` after a pull (only ones it generated
earlier, and only when `~/.agents/skills/delegate-build` links into the clone
you run it from; it never creates them). The manual equivalent:

    mkdir -p ~/.agents/skills
    ln -s "$REPO/delegate-build" ~/.agents/skills/delegate-build
    "$REPO/bin/roster-render" --codex ~/.codex/agents

`bin/roster-render --codex <dir> [--check] [--refresh]` renders into any
directory you name, and `--claude <dir> [--check]` does the same for the four
Claude agents, which is how a staged run gets pinned copies; add `--check` to
verify a directory without writing. A symlink at a target path, or a file the
renderer did not generate, is an error in a write and in `--check`, and is
skipped silently under `--refresh`, which only touches files it generated
(that is what plain `bin/install` runs). The agent file format was verified
against Codex CLI 0.159.2.

Start the main loop with `codex --sandbox workspace-write --ask-for-approval
on-request` and invoke the skill as `$delegate-build`. The main loop must be
GPT-6 Astra, and it cannot see its own model slug, so unless you named the
model in the session it asks you to confirm it before announcing; on any other
model it skips itself. Under approval policy `never`
(or a granular policy with sandbox approvals off) it stops before Phase 1,
since commits and the lane wrappers need escalation. Workers inherit the main
loop's sandbox, so the scout and researcher are read-only by their instructions
only. [delegate-build/codex.md](delegate-build/codex.md) covers the rest:
approvals, escalating the Kimi and Claude wrappers out of Codex's sandbox, and
why the GPT lane is not offered from Codex.

## Optional: status line

Needs `node`. In `~/.claude/settings.json`, the one place that needs a literal
path; point it at your clone:

    "statusLine": {
      "type": "command",
      "command": "node \"/path/to/skills/trim/statusline.js\""
    }

The context bar reports raw tokens against the full window, and its colour
bands assume autocompact is off, so they mark proximity to a hard wall. With
autocompact enabled your session compacts well before the top bands, and the
number no longer predicts when.

## Optional: delegate-build review lanes

delegate-build Phase 4 runs whichever of these are installed and reports the
ones it skipped. None is required; with none of them the phase falls back to
the in-session `claude-reviewer` agent (Claude Code only) or is skipped. Lanes
are named by model family (Claude, GPT, Kimi); the model inside a lane and the
path that reaches it are pinned in `roster.conf` and can change without
renaming the lane.

| Lane | Needs | Notes |
| --- | --- | --- |
| GPT (via Codex) | the `openai/codex-plugin-cc` Claude Code plugin | read-only by the plugin's own default. The lane dispatches the plugin's own `/codex:rescue` command, not one defined here: the plugin's dedicated `/codex:review` commands are user-invocable only, so delegate-build frames the fix-capable rescue agent as review-only by prompt |
| Kimi (via OpenCode) | `opencode`, a Kimi provider, and `srt` | model and optional reasoning variant pinned from `roster.conf` at the repo root; change the slug there if your provider spells it differently |
| Claude (sandboxed, opt-in) | `claude` on PATH and `srt` | model and effort pinned from `roster.conf` at the repo root |

Every lane takes its model and effort from `roster.conf` at the repo root, the
one place either is set. The wrappers read it at launch, so an edit there is
live with no reinstall; only the Codex agent files are copies, reached by
`bin/install`. [ROSTER.md](ROSTER.md) explains the roles and which key
feeds which lane, and `bin/doctor` prints the pins each lane will use.

From a Codex main loop, the Kimi and Claude lanes run the same wrappers through
`~/.agents/skills/delegate-build/sandbox/`, each escalated out of Codex's
sandbox because srt cannot start inside it. The GPT lane is that loop's own
lineage and is not offered, and there is no in-session Claude fallback.

The two sandboxed lanes refuse to run without the sandbox runtime rather than
degrading to an unsandboxed run:

    npm i -g @anthropic-ai/sandbox-runtime

Those wrappers also neutralize Director, a separate session-coordination CLI
of mine that is not part of this repo. If you don't have it, that wiring costs
nothing and can stay as it is.

## Optional: Claude Code Bash sandbox

Off in my own settings, so treat it as opt-in rather than recommended. It
trades permission prompts for a Seatbelt boundary: sandboxed commands run
without prompting, anything escaping the sandbox prompts individually. That
trade is worth it when you want commands to auto-run inside a boundary, and it
gets in the way when your work routinely reaches outside one. Try it, and turn
it off if the escapes outnumber the saved prompts:

    "sandbox": {
      "enabled": true,
      "excludedCommands": [
        "docker *", "gh *",
        "git push", "git push *",
        "git pull", "git pull *",
        "git fetch", "git fetch *",
        "git -C *"
      ],
      "filesystem": {
        "allowWrite": ["~/.director"]
      }
    },

`excludedCommands` covers the documented macOS incompatibilities (docker's
daemon architecture, gh's Go TLS verification under Seatbelt) plus network
git: SSH cannot negotiate through the sandbox proxy, and the `git -C *`
entry is the backstop for command shapes the plain patterns miss. Grow
`allowWrite` from evidence: the standing out-of-workspace writers you
actually hit (`~/.director` is my session-coordination log, drop it if you
don't run Director).

This is independent of the review-lane sandboxing above. The lanes wrap
themselves in `srt` whatever this setting says.

## Harness snapshots

`bin/fetch-harness-prompts` refreshes `harness-snapshots/{codex,opencode}/`
from the installed Codex binary and the sst/opencode repo; narrow it with
`--only codex` or `--only opencode` if you have just one. The fetcher needs
Python 3.11+ and dies when a requested harness is absent, so on a Claude-only
install a non-zero exit here is the expected steady state: the
`audit-directives` skill reports the failed fetch and audits against the
committed snapshots instead.
`harness-snapshots/claude-code/` is generated from inside a live session by
the `audit-directives` skill and intentionally left untracked; see
[harness-snapshots/README.md](harness-snapshots/README.md).
