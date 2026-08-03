#!/usr/bin/env bash
# Sandboxed Opus review lane for opus-build Phase 4 — the STANDARD Opus review
# path; the in-session `opus-reviewer` agent is the fallback for machines
# without srt. Wraps headless `claude -p --model claude-opus-5` in srt,
# mirroring k3-review.sh: repo readable but not writable, writes confined to
# Claude's own state dir + temp space, network to the Anthropic API only. Two
# boundaries: the tool allowlist keeps the reviewer read-only at the harness
# layer, srt repeats it at the OS layer. Reviewers never need write access, so
# the boundary costs nothing — this is least privilege, not distrust of Opus.
# Bills the Opus half of the Anthropic quota — NOT a no-cost lane like Codex/K3.
set -euo pipefail

command -v srt >/dev/null 2>&1 || {
  echo "opus-review: srt not found — install: npm i -g @anthropic-ai/sandbox-runtime" >&2
  echo "opus-review: refusing to run the Opus reviewer unsandboxed" >&2
  exit 127
}
command -v claude >/dev/null 2>&1 || {
  echo "opus-review: claude CLI not found on PATH" >&2
  exit 127
}

[ $# -eq 1 ] || { echo "usage: opus-review.sh \"<review prompt>\"" >&2; exit 2; }

# pwd -P: the rubric lives outside the skill dir, so the repo path must resolve
# even when this runs through the ~/.claude/skills/opus-build symlink.
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
rubric_file="$dir/../../agents/opus-reviewer.md"

[ -r "$rubric_file" ] || {
  echo "opus-review: review rubric not found at $rubric_file" >&2
  exit 66
}

# Single-source the review contract: the `opus-reviewer` agent definition's body
# IS the rubric, so this lane and the in-session agent cannot drift. Strip the
# YAML frontmatter — print only what follows the second `---`. Read here, before
# the exec, so the rubric load happens outside the sandbox.
rubric="$(awk 'f>1; /^---[[:space:]]*$/{f++}' "$rubric_file")"
[ -n "$rubric" ] || {
  echo "opus-review: rubric body empty after frontmatter strip — check $rubric_file" >&2
  exit 65
}

# srt-specific addendum only. The read-only contract, the no-director rule, and
# the deliverable format all come from the rubric above.
# env -u CLAUDECODE: the child must not think it's nested inside this session.
# DIRECTOR_BIN=/dev/null: same two-layer Director kill as the K3 lane — sole
#   resolution candidate, non-executable, so every hook degrades to a no-op.
#   Director is my separate session-coordination CLI, not part of this repo; if
#   you don't have it this costs nothing and can stay as-is.
# --strict-mcp-config with no --mcp-config: zero MCP servers — none are needed
#   to read a diff, and their sockets/hosts are blocked by srt anyway.
# --effort xhigh: explicit rather than inherited from ~/.claude/settings.json,
#   so the lane's reasoning depth doesn't silently follow the user's session.
sandbox_note="You are running under an OS sandbox: any write outside temp space \
is mechanically rejected, and a rejected action can kill your process."

# Hand the prompt over the environment rather than inlining it in the command
# string: `printf %q` switches to ANSI-C $'...' quoting as soon as the text
# contains newlines, and a /bin/sh that doesn't parse that form would pass the
# literal $'...' through as the prompt — the reviewer would then review against
# a garbled rubric and still return a plausible-looking report. srt forwards the
# environment to the sandboxed command, so plain POSIX $VAR expansion suffices.
export OPUS_REVIEW_PROMPT="$rubric

$sandbox_note

$1"

# \$OPUS_REVIEW_PROMPT is escaped so the INNER shell expands it, not this one.
# Prompt goes right after -p: --allowedTools is variadic and would swallow a
# trailing positional argument.
opus_model="${OPUS_MODEL:-claude-opus-5}"

exec srt --settings "$dir/opus-srt-settings.json" -c "env -u CLAUDECODE DIRECTOR_BIN=/dev/null claude -p \"\$OPUS_REVIEW_PROMPT\" --model $opus_model --effort xhigh --strict-mcp-config --allowedTools 'Read,Grep,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git status:*)'"
