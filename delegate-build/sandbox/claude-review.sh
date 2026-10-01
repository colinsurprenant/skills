#!/usr/bin/env bash
# Sandboxed Claude review lane for delegate-build Phase 4 — the STANDARD Claude
# review path; under Claude Code the in-session `claude-reviewer` agent is the
# fallback for machines without srt (a Codex main loop has no such fallback and
# goes without the lane). Wraps headless `claude -p` (model and effort pinned
# from roster.conf) in srt, mirroring kimi-review.sh: repo readable but not
# writable, writes confined to Claude's own state dir + temp space, network to
# the Anthropic API only. Two boundaries: the tool allowlist keeps the reviewer
# read-only at the harness layer, srt repeats it at the OS layer. Reviewers
# never need write access, so the boundary costs nothing — this is least
# privilege, not distrust of the reviewer. Bills the Anthropic quota —
# NOT a no-cost lane like GPT/Kimi.
set -euo pipefail

dry_run=""
if [ "${1-}" = "--dry-run" ]; then dry_run=1; shift; fi

[ $# -eq 1 ] || { echo "usage: claude-review.sh [--dry-run] \"<review prompt>\"" >&2; exit 2; }

# --dry-run assembles and prints the command without running it, so the pins
# can be verified on a machine that has no sandbox runtime installed.
if [ -z "$dry_run" ]; then
  command -v srt >/dev/null 2>&1 || {
    echo "claude-review: srt not found — install: npm i -g @anthropic-ai/sandbox-runtime" >&2
    echo "claude-review: refusing to run the Claude reviewer unsandboxed" >&2
    exit 127
  }
  command -v claude >/dev/null 2>&1 || {
    echo "claude-review: claude CLI not found on PATH" >&2
    exit 127
  }
fi

# pwd -P: the rubric and roster live outside the skill dir, so the repo path
# must resolve even when this runs through the ~/.claude/skills/delegate-build
# symlink (Claude Code) or the ~/.agents/skills/delegate-build symlink (Codex).
# Resolve the script dir physically FIRST, then walk up: appending `/../..` to
# an unresolved dirname is canonicalized textually and would land in
# ~/.claude/skills or ~/.agents/skills instead of the repo.
dir="$(CDPATH='' cd -P -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(CDPATH='' cd -P -- "$dir/../.." && pwd -P)"
rubric_file="$dir/../../agents/claude-reviewer.md"

# Model and effort come from roster.conf at the repo root — the single place
# models and efforts are set, so no pin lives in this file. Read through
# bin/roster-get, the one reader every consumer of roster.conf goes through: it
# validates the whole file (never `source`), refuses duplicate keys and empty
# values, and owns the message. Its exit status is 78 too, so a config fault
# reads the same from every lane.
reader="$root/bin/roster-get"
[ -x "$reader" ] || {
  echo "claude-review: roster reader not found or not executable at $reader" >&2
  exit 78
}

claude_model="$("$reader" CLAUDE_REVIEWER_MODEL)" || exit 78
claude_effort="$("$reader" CLAUDE_REVIEWER_EFFORT)" || exit 78

[ -r "$rubric_file" ] || {
  echo "claude-review: review rubric not found at $rubric_file" >&2
  exit 66
}

# Single-source the review contract: the `claude-reviewer` agent definition's body
# IS the rubric, so this lane and the in-session agent cannot drift. Strip the
# YAML frontmatter — print only what follows the second `---`. Read here, before
# the exec, so the rubric load happens outside the sandbox.
rubric="$(awk 'f>1; /^---[[:space:]]*$/{f++}' "$rubric_file")"
[ -n "$rubric" ] || {
  echo "claude-review: rubric body empty after frontmatter strip — check $rubric_file" >&2
  exit 65
}

# srt-specific addendum only. The read-only contract, the no-director rule, and
# the deliverable format all come from the rubric above.
# env -u CLAUDECODE: the child must not think it's nested inside this session.
# DIRECTOR_BIN=/dev/null: same two-layer Director kill as the Kimi lane — sole
#   resolution candidate, non-executable, so every hook degrades to a no-op.
#   Director is my separate session-coordination CLI, not part of this repo; if
#   you don't have it this costs nothing and can stay as-is.
# --strict-mcp-config with no --mcp-config: zero MCP servers — none are needed
#   to read a diff, and their sockets/hosts are blocked by srt anyway.
# --model / --effort: pinned from roster.conf rather than inherited from
#   ~/.claude/settings.json, so the lane's model and reasoning depth don't
#   silently follow the user's session.
sandbox_note="You are running under an OS sandbox: any write outside temp space \
is mechanically rejected, and a rejected action can kill your process."

# Hand the prompt over the environment rather than inlining it in the command
# string: `printf %q` switches to ANSI-C $'...' quoting as soon as the text
# contains newlines, and a /bin/sh that doesn't parse that form would pass the
# literal $'...' through as the prompt — the reviewer would then review against
# a garbled rubric and still return a plausible-looking report. srt forwards the
# environment to the sandboxed command, so plain POSIX $VAR expansion suffices.
export CLAUDE_REVIEW_PROMPT="$rubric

$sandbox_note

$1"

# \$CLAUDE_REVIEW_PROMPT is escaped so the INNER shell expands it, not this one.
# Prompt goes right after -p: --allowedTools is variadic and would swallow a
# trailing positional argument.
cmd="env -u CLAUDECODE DIRECTOR_BIN=/dev/null claude -p \"\$CLAUDE_REVIEW_PROMPT\" --model $(printf '%q' "$claude_model") --effort $(printf '%q' "$claude_effort") --strict-mcp-config --allowedTools 'Read,Grep,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git status:*)'"

if [ -n "$dry_run" ]; then
  printf '%s\n' "$cmd"
  exit 0
fi

# Tee stdout to a temp report file (path announced on stderr) so a finished
# review survives a killed run or an orchestrator that dies before recording
# it — same durability move as the Kimi lane. No exec: the pipeline needs this
# shell; pipefail propagates srt's status.
# mktemp, not a hand-built name: a predictable path under world-writable /tmp
# is a symlink-attack target; mktemp creates the file itself, 0600.
report="$(mktemp "${TMPDIR:-/tmp}/claude-review-XXXXXX")"
echo "claude-review: tee'ing report to $report" >&2

srt --settings "$dir/claude-srt-settings.json" -c "$cmd" < /dev/null | tee "$report"
