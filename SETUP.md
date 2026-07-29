# Setup

Everything is delivered by symlinks from harness config directories into this
repo. Clone it anywhere; the links below are location-independent (the
CLAUDE.md `@`-import is relative and resolves through the symlink's real
path):

    git clone https://github.com/colinsurprenant/skills
    REPO="$PWD/skills"    # or wherever you cloned it

## Claude Code

    ln -s "$REPO/CLAUDE.global.md"       ~/.claude/CLAUDE.md
    ln -s "$REPO/audit-directives"       ~/.claude/skills/audit-directives
    ln -s "$REPO/opus-build"             ~/.claude/skills/opus-build
    ln -s "$REPO/agents/opus-builder.md" ~/.claude/agents/opus-builder.md
    ln -s "$REPO/commands/iterate.md"    ~/.claude/commands/iterate.md

`CLAUDE.global.md` `@`-imports `AGENT_BEHAVIOR.md`, which delivers the
behavior file to every session and non-fork subagent, from any entry point.
Skill and agent bodies resolve through the symlinks at invocation time:
edits land live, no session restart needed (only the name/description
listings are snapshotted at session start).

Status line, in `~/.claude/settings.json` (the one place that needs a literal
path; point it at your clone):

    "statusLine": {
      "type": "command",
      "command": "node \"/path/to/skills/trim/statusline.js\""
    }

## Codex CLI and OpenCode

Both consume `AGENT_BEHAVIOR.md` whole through their `AGENTS.md` mechanism;
neither processes `@`-imports, which is why the file is self-contained:

    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.codex/AGENTS.md
    ln -s "$REPO/AGENT_BEHAVIOR.md" ~/.config/opencode/AGENTS.md

## Sandboxing

The opus-build K3 review lane requires Anthropic's sandbox runtime; the
bundled wrapper (`opus-build/sandbox/k3-review.sh`) refuses to run without
it:

    npm i -g @anthropic-ai/sandbox-runtime

Claude Code's native Bash sandbox, in `~/.claude/settings.json`. Sandboxed
commands run without permission prompts; anything escaping the sandbox
prompts individually:

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
    "permissions": {
      "ask": ["Bash(dangerouslyDisableSandbox:true)"]
    }

`excludedCommands` covers the documented macOS incompatibilities (docker's
daemon architecture, gh's Go TLS verification under Seatbelt) plus network
git: SSH cannot negotiate through the sandbox proxy, and the `git -C *`
entry is the backstop for command shapes the plain patterns miss. Grow
`allowWrite` from evidence: the standing out-of-workspace writers you
actually hit (`~/.director` is my session-coordination log). Leave one-off
escapes to the ask rule.

## Harness snapshots

`bin/fetch-harness-prompts` refreshes `harness-snapshots/{codex,opencode}/`
from the installed Codex binary and the sst/opencode repo.
`harness-snapshots/claude-code/` is generated from inside a live session by
the `audit-directives` skill and intentionally left untracked; see
[harness-snapshots/README.md](harness-snapshots/README.md).
