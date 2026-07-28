# Setup

Everything is delivered by symlinks from harness config directories into this
repo. Clone it anywhere — the links below are location-independent (the
CLAUDE.md `@`-import is relative and resolves through the symlink's real
path):

    git clone https://github.com/colinsurprenant/skills
    REPO="$PWD/skills"    # or wherever you cloned it

## Claude Code

    ln -s "$REPO/CLAUDE.global.md"       ~/.claude/CLAUDE.md
    ln -s "$REPO/audit-directives"       ~/.claude/skills/audit-directives
    ln -s "$REPO/opus-build"             ~/.claude/skills/opus-build
    ln -s "$REPO/commands/iterate.md"    ~/.claude/commands/iterate.md
    ln -s "$REPO/commands/w.md"          ~/.claude/commands/w.md
    ln -s "$REPO/agents/opus-builder.md" ~/.claude/agents/opus-builder.md

`CLAUDE.global.md` `@`-imports `AGENT_BEHAVIOR.md`, which delivers the
behavior file to every session and non-fork subagent, from any entry point.
Skill, command, and agent bodies resolve through the symlinks at invocation
time — edits land live, no session restart needed (only the name/description
listings are snapshotted at session start).

Status line, in `~/.claude/settings.json` (the one place that needs a literal
path — point it at your clone):

    "statusLine": {
      "type": "command",
      "command": "node \"/path/to/skills/statusline.js\""
    }

## Codex CLI and OpenCode

Both consume `AGENT_BEHAVIOR.md` whole through their `AGENTS.md` mechanism —
neither processes `@`-imports, which is why the file is self-contained:

    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.codex/AGENTS.md
    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.config/opencode/AGENTS.md

## Harness snapshots

`bin/fetch-harness-prompts` refreshes `harness-snapshots/{codex,opencode}/`
from the installed Codex binary and the sst/opencode repo.
`harness-snapshots/claude-code/` is generated from inside a live session by
the `audit-directives` skill and intentionally left untracked — see
[harness-snapshots/README.md](harness-snapshots/README.md).
