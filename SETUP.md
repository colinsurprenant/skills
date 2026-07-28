# Setup

How this repo is wired into the machine. Everything is a symlink from a
harness config directory into a clone at `~/dev/src/skills`; clone elsewhere
and adjust paths (one file hardcodes the location: the
`@~/dev/src/skills/AGENT_BEHAVIOR.md` import in `CLAUDE.global.md`).

## Claude Code

| Link | Target (in this repo) |
| --- | --- |
| `~/.claude/CLAUDE.md` | `CLAUDE.global.md` |
| `~/.claude/skills/audit-directives` | `audit-directives/` |
| `~/.claude/skills/opus-build` | `opus-build/` |
| `~/.claude/commands/iterate.md` | `commands/iterate.md` |
| `~/.claude/commands/w.md` | `commands/w.md` |
| `~/.claude/agents/opus-builder.md` | `agents/opus-builder.md` |

`CLAUDE.global.md` `@`-imports `AGENT_BEHAVIOR.md`, which delivers the
behavior file to every session and non-fork subagent, from any entry point.
Skill, command, and agent bodies resolve through the symlinks at invocation
time — edits land live, no session restart needed (only name/description
listings are snapshotted at session start).

Status line, in `~/.claude/settings.json`:

    "statusLine": {
      "type": "command",
      "command": "node \"/path/to/skills/statusline.js\""
    }

## Codex CLI and OpenCode

Both consume `AGENT_BEHAVIOR.md` whole through their `AGENTS.md` mechanism —
neither processes `@`-imports, which is why the file is self-contained:

| Link | Target (in this repo) |
| --- | --- |
| `~/.codex/AGENTS.md` | `AGENT_BEHAVIOR.md` |
| `~/.config/opencode/AGENTS.md` | `AGENT_BEHAVIOR.md` |

## Harness snapshots

`bin/fetch-harness-prompts` refreshes `harness-snapshots/{codex,opencode}/`
from the installed Codex binary and the sst/opencode repo.
`harness-snapshots/claude-code/` is generated from inside a live session by
the `audit-directives` skill and intentionally left untracked — see
[harness-snapshots/README.md](harness-snapshots/README.md).
