#!/usr/bin/env bash
# Sandboxed K3 review lane for opus-build Phase 4.
# Override the model with K3_MODEL if your OpenCode provider uses another slug.
# Wraps `opencode run -m kimi-for-coding/k3` in srt (@anthropic-ai/sandbox-runtime):
# writes are confined to OpenCode's own state dirs + temp space, network to the
# Kimi API and the model catalogs (models.dev, models.opencode.ai). The repo
# stays readable but not writable —
# OpenCode has no OS-level sandbox of its own, and this lane runs an open-weight
# model headless, so the boundary must be mechanical, not model judgment.
set -euo pipefail

command -v srt >/dev/null 2>&1 || {
  echo "k3-review: srt not found — install: npm i -g @anthropic-ai/sandbox-runtime" >&2
  echo "k3-review: refusing to run the K3 reviewer unsandboxed" >&2
  exit 127
}

[ $# -eq 1 ] || { echo "usage: k3-review.sh \"<review prompt>\"" >&2; exit 2; }

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

k3_model="${K3_MODEL:-kimi-for-coding/k3}"

report="${TMPDIR:-/tmp}/k3-review-$(date +%Y%m%d-%H%M%S)-$$.md"
echo "k3-review: tee'ing report to $report" >&2

# No exec: the pipeline needs this shell. pipefail propagates srt's status.
srt --settings "$dir/srt-settings.json" -c "DIRECTOR_BIN=/dev/null opencode run -m $k3_model $(printf '%q' "$preamble $1")" < /dev/null | tee "$report"
