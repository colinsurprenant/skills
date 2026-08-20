# Setup

This repo is a menu, not a bundle. Claude Code plus a handful of symlinks is
the whole required install; everything else (Codex, OpenCode, Kimi K3,
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
    bin/install --all      # plus the Codex, OpenCode, and Copilot CLI links

Idempotent and non-clobbering: a link already resolving to its documented
target is left alone, and anything else found at a target path, a stray
file or a link to the wrong place, is reported and kept, never replaced. The manual sections below are the same links spelled out,
kept for transparency and for partial installs.

## Update

    git pull
    bin/install

Content updates need only the pull: skill and agent bodies resolve through
the symlinks at invocation time, so pulled edits are live immediately (only
the name and description listings snapshot at session start). Rerunning
`bin/install` covers the remaining case, a pull that introduces a new link;
it is a no-op otherwise and ends with the doctor report.

## Check what you have

    bin/doctor

Reports which tools are installed, which symlinks resolve into this clone, and
which opus-build review lanes are live. Run it again after any step below.
`bin/doctor --deep` additionally verifies the OpenCode model slug, which needs
network. Unmet optional checks are informational: they tell you which lane is
retired, not that something is broken. The exit status scores only the
required checks, so a Claude-only install exits 0.

## Required: Claude Code

    mkdir -p ~/.claude/skills ~/.claude/agents ~/.claude/commands
    ln -s "$REPO/CLAUDE.global.md"        ~/.claude/CLAUDE.md
    ln -s "$REPO/audit-directives"        ~/.claude/skills/audit-directives
    ln -s "$REPO/opus-build"              ~/.claude/skills/opus-build
    ln -s "$REPO/agents/opus-builder.md"  ~/.claude/agents/opus-builder.md
    ln -s "$REPO/agents/opus-reviewer.md" ~/.claude/agents/opus-reviewer.md
    ln -s "$REPO/agents/researcher.md"    ~/.claude/agents/researcher.md
    ln -s "$REPO/commands/iterate.md"     ~/.claude/commands/iterate.md

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

## Optional: opus-build review lanes

opus-build Phase 4 runs whichever of these are installed and reports the ones
it skipped. None is required; with none of them the phase falls back to the
in-session `opus-reviewer` agent or is skipped.

| Lane | Needs | Notes |
| --- | --- | --- |
| Codex | the `openai/codex-plugin-cc` Claude Code plugin | read-only by the plugin's own default |
| Kimi K3 | `opencode`, a Kimi provider, and `srt` | set `K3_MODEL` if your provider slug differs from `kimi-for-coding/k3` |
| Opus (sandboxed) | `claude` on PATH and `srt` | set `OPUS_MODEL` to override the pinned model |

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
