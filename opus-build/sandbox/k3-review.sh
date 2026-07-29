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
exec srt --settings "$dir/srt-settings.json" -c "opencode run -m kimi-for-coding/k3 $(printf '%q' "$1")"
