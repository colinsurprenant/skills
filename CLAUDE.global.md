# CLAUDE.md

@AGENT_BEHAVIOR.md

<!-- Durable personal preferences only — things Claude can't derive (conventions, tool choices, standing rules). Behavior rules live in AGENT_BEHAVIOR.md, delivered everywhere (main sessions + non-fork subagents, any entry point) by the import above. -->

Prefer standalone Bash commands over `&&` chains. Permission allow-rules and
sandbox exclusions are matched per subcommand, so one unmatched link (a bare
`cd`, a `.venv/bin/…` spelling) forces an approval prompt for the whole chain.
Chain only when steps genuinely depend on shared shell state, and spell
commands the way the project's allowlist spells them (check `.claude/settings.json`
before inventing a new invocation of a routinely used tool).

Strict case of the above — network git operations (push, pull, fetch): always
standalone commands from the repo's directory, never inside `&&` chains and
never with `-C`. Chained or `-C` forms miss the sandbox exclusion list and
trigger approval prompts.

Multi-line text destined for an external tool (`gh pr create/edit/comment`
bodies, and anything similar) goes through a file, never an inline
`"$(cat <<'EOF' …)"` argument: the harness shell executes backtick spans
inside the heredoc (they vanish from the posted text, and their output leaks
as errors) and can append the heredoc terminator to the body. Write the text
with the Write tool, then pass `--body-file <path>` (or the tool's file
flag). Proven on a mangled PR body, 2026-08-19.
