#!/usr/bin/env bash
# Sandboxed K3 review lane for opus-build Phase 4.
# Wraps `opencode run -m kimi-for-coding/k3` in srt (@anthropic-ai/sandbox-runtime):
# writes are confined to OpenCode's own state dirs + temp space, network to the
# Kimi API and the models.dev catalog. The repo stays readable but not writable —
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

# Two layers keep Director out of this lane (seen live: a `director emit`
# attempt was rejected by srt and lost a finished review's report):
#   1. DIRECTOR_BIN=/dev/null — the universal kill switch both the OpenCode
#      plugin and the CC shims honor: sole resolution candidate, non-executable,
#      so every hook degrades to a no-op. No digest injection, no fleet rows —
#      the reviewer never hears about Director at all.
#   2. The preamble below — covers what the kill switch can't: K3 reading
#      about the director CLI in ambient repo docs and trying it anyway.
# Deliver the verdict on stdout; the orchestrating session records it.
preamble="You run READ-ONLY under an OS sandbox: any write outside temp space \
is mechanically rejected, and a rejected action can kill your process. Never \
run the 'director' CLI or any other state-writing command. Print your complete \
verdict as your final message — the session that launched you records it."

exec srt --settings "$dir/srt-settings.json" -c "DIRECTOR_BIN=/dev/null opencode run -m kimi-for-coding/k3 $(printf '%q' "$preamble $1")"
