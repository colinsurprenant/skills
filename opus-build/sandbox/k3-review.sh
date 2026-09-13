#!/usr/bin/env bash
# Sandboxed K3 review lane for opus-build Phase 4.
# Wraps `opencode run` (model pinned from roster.conf) in srt
# (@anthropic-ai/sandbox-runtime):
# writes are confined to OpenCode's own state dirs + temp space, network to the
# Kimi API and the model catalogs (models.dev, models.opencode.ai). The repo
# stays readable but not writable —
# OpenCode has no OS-level sandbox of its own, and this lane runs an open-weight
# model headless, so the boundary must be mechanical, not model judgment.
set -euo pipefail

dry_run=""
if [ "${1-}" = "--dry-run" ]; then dry_run=1; shift; fi

[ $# -eq 1 ] || { echo "usage: k3-review.sh [--dry-run] \"<review prompt>\"" >&2; exit 2; }

# --dry-run assembles and prints the command without running it, so the pin
# can be verified on a machine that has no sandbox runtime installed.
if [ -z "$dry_run" ] && ! command -v srt >/dev/null 2>&1; then
  echo "k3-review: srt not found — install: npm i -g @anthropic-ai/sandbox-runtime" >&2
  echo "k3-review: refusing to run the K3 reviewer unsandboxed" >&2
  exit 127
fi

# Resolve the script dir physically FIRST, then walk up: `dirname $0/../..`
# would be canonicalized textually against the logical path and land in
# ~/.claude/skills when this runs through the ~/.claude/skills/opus-build
# symlink. Two steps, both -P, reach the real repo root either way.
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$dir/../.." && pwd -P)"

# Model and reasoning variant come from roster.conf at the repo root — the
# single place models and efforts are set, so no pin lives in this file. Read
# through bin/roster-get, the one reader every consumer of roster.conf goes
# through: it validates the whole file (never `source`), refuses duplicate keys
# and empty values, and owns the message. Its exit status is 78 too, so a
# config fault reads the same from every lane.
reader="$root/bin/roster-get"
[ -x "$reader" ] || {
  echo "k3-review: roster reader not found or not executable at $reader" >&2
  exit 78
}

k3_model="$("$reader" K3_MODEL)" || exit 78
# K3_VARIANT is the provider-specific reasoning effort. The key must be present
# — an absent key is a config fault like any other — but an empty value is a
# real setting: omit the flag and take the provider default.
k3_variant="$("$reader" K3_VARIANT)" || exit 78
variant_arg=""
if [ -n "$k3_variant" ]; then
  variant_arg=" --variant $(printf '%q' "$k3_variant")"
fi

# Director is my separate session-coordination CLI, not part of this repo. If you
# don't have it these two layers cost nothing and can stay as-is.
# Two layers keep Director out of this lane (seen live: a `director emit`
# attempt was rejected by srt and lost a finished review's report):
#   1. DIRECTOR_BIN=/dev/null — the universal kill switch both the OpenCode
#      plugin and the CC shims honor: sole resolution candidate, non-executable,
#      so every hook degrades to a no-op. No digest injection, no fleet rows —
#      the reviewer never hears about Director at all.
#   2. The preamble below — covers what the kill switch can't: K3 reading
#      about the director CLI in ambient repo docs and trying it anyway.
# Deliver the verdict on stdout; the orchestrating session records it. Stdout
# is also tee'd to a temp report file (path announced on stderr at launch) so a
# finished review survives a killed run or an orchestrator that dies before
# recording it — the cheap substitute for the reviewer-side write channel that
# was considered and rejected.
preamble="You run READ-ONLY under an OS sandbox: any write outside temp space \
is mechanically rejected, and a rejected action can kill your process. Never \
run the 'director' CLI or any other state-writing command. Print your complete \
verdict as your final message — the session that launched you records it."

# Hand the prompt over the environment rather than inlining it in the command
# string: `printf %q` switches to ANSI-C $'...' quoting as soon as the text
# contains newlines, and a /bin/sh that doesn't parse that form would pass the
# literal $'...' through as the prompt — the reviewer would then review against
# a garbled brief and still return a plausible-looking report. srt forwards the
# environment to the sandboxed command (verified with these settings), so plain
# POSIX $VAR expansion suffices. Same mechanism as the Opus lane.
export K3_REVIEW_PROMPT="$preamble $1"

# \$K3_REVIEW_PROMPT is escaped so the INNER shell expands it, not this one.
cmd="DIRECTOR_BIN=/dev/null opencode run -m $(printf '%q' "$k3_model")$variant_arg \"\$K3_REVIEW_PROMPT\""

if [ -n "$dry_run" ]; then
  printf '%s\n' "$cmd"
  exit 0
fi

# mktemp, not a hand-built name: a predictable path under world-writable /tmp
# is a symlink-attack target; mktemp creates the file itself, 0600.
report="$(mktemp "${TMPDIR:-/tmp}/k3-review-XXXXXX")"
echo "k3-review: tee'ing report to $report" >&2

# No exec: the pipeline needs this shell. pipefail propagates srt's status.
srt --settings "$dir/srt-settings.json" -c "$cmd" < /dev/null | tee "$report"
