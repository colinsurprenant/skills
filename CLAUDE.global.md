# CLAUDE.md

@AGENT_BEHAVIOR.md

<!-- Durable personal preferences only — things Claude can't derive (conventions, tool choices, standing rules). Behavior rules live in AGENT_BEHAVIOR.md, delivered everywhere (main sessions + non-fork subagents, any entry point) by the import above. -->

Run network git operations (push, pull, fetch) as standalone commands from
the repo's directory: never inside `&&` chains and never with `-C`. Chained
or `-C` forms miss the sandbox exclusion list and trigger approval prompts.
