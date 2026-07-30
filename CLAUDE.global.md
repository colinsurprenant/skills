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
