#!/usr/bin/env node
// Claude Code Statusline
// Originally based on GSD's gsd-statusline.js (v1.26.0), kept after GSD removal.
// Shows: shell prefix (venv, user@host, git branch, cwd) | model + context tokens | current task | context usage bar

const fs = require('fs');
const path = require('path');
const os = require('os');

// Read JSON from stdin
let input = '';
// Timeout guard: if stdin doesn't close within 3s (e.g. pipe issues on
// Windows/Git Bash), exit silently instead of hanging. See #775.
const stdinTimeout = setTimeout(() => process.exit(0), 3000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const dir = data.workspace?.current_dir || process.cwd();
    const session = data.session_id || '';
    const remaining = data.context_window?.remaining_percentage;

    // Diagnostic only since the display moved to raw tokens: emitted as
    // buffer_pct in the bridge file and the debug log, it no longer normalizes
    // anything shown. Buffer = bottom slice reclaimed by autocompact; honors
    // CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (env or settings.json env block);
    // defaults to ~16.5% when unset/invalid.
    const ovr = Number(process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE);
    const AUTO_COMPACT_BUFFER_PCT =
      Number.isFinite(ovr) && ovr >= 0 && ovr < 100 ? ovr : 16.5;

    const fmtK = (n) => {
      if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
      if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
      return String(n);
    };
    const u = data.context_window?.current_usage;
    const usedTokens = u
      ? (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0)
      : 0;
    const windowSize = data.context_window?.context_window_size;
    let model = data.model?.display_name || 'Claude';
    if (usedTokens > 0 && windowSize) {
      const ctxStr = `(${fmtK(usedTokens)} / ${fmtK(windowSize)} context)`;
      model = /\([^)]*context\)/.test(model)
        ? model.replace(/\([^)]*context\)/, ctxStr)
        : `${model} ${ctxStr}`;
    }
    if (data.effort?.level) model += ` ${data.effort.level}`;
    let ctx = '';
    if (remaining != null) {
      // Faithful percentage: raw tokens over the model's full context window
      const used = windowSize && usedTokens > 0
        ? Math.max(0, Math.min(100, Math.round((100 * usedTokens) / windowSize)))
        : Math.max(0, Math.min(100, Math.round(100 - remaining)));

      // Write context metrics to a bridge file other hooks/tools can read.
      if (session) {
        try {
          const bridgePath = path.join(os.tmpdir(), `claude-ctx-${session}.json`);
          const bridgeData = JSON.stringify({
            session_id: session,
            remaining_percentage: remaining,
            used_pct: used,
            used_tokens: usedTokens,
            window_size: windowSize,
            raw_used_pct: windowSize ? +(100 * usedTokens / windowSize).toFixed(2) : null,
            buffer_pct: AUTO_COMPACT_BUFFER_PCT,
            context_window_full: data.context_window,
            timestamp: Math.floor(Date.now() / 1000)
          });
          fs.writeFileSync(bridgePath, bridgeData);

          // Append-only debug log: one line per statusline tick when used_percentage changes.
          // Used to diagnose actual autocompact trigger thresholds vs CLAUDE_AUTOCOMPACT_PCT_OVERRIDE.
          const logPath = path.join(os.tmpdir(), `claude-ctx-${session}.log`);
          const usedPct = data.context_window?.used_percentage;
          const lastLine = fs.existsSync(logPath) ? (fs.readFileSync(logPath, 'utf8').trim().split('\n').pop() || '') : '';
          const lastUsedPct = lastLine ? Number((lastLine.match(/used_pct=(\d+)/) || [])[1]) : null;
          if (usedPct != null && usedPct !== lastUsedPct) {
            const line = `${new Date().toISOString()} used_pct=${usedPct} remaining=${remaining} used_tokens=${usedTokens} window=${windowSize} override=${AUTO_COMPACT_BUFFER_PCT}\n`;
            fs.appendFileSync(logPath, line);
          }
        } catch (e) {
          // Silent fail -- bridge is best-effort, don't break statusline
        }
      }

      // Build progress bar (10 segments)
      const filled = Math.floor(used / 10);
      const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

      // Color on absolute tokens (200k/400k on a 1M window), capped so the
      // thresholds can never sit past 70%/90% of a smaller window — on a 200k
      // window that lands at 140k/180k. Autocompact is off, so the wall is
      // terminal and a small window has to warn on proximity, not on load.
      const warnAt = Math.min(200_000, 0.70 * (windowSize || 200_000));
      const critAt = Math.min(400_000, 0.90 * (windowSize || 200_000));
      if (usedTokens < warnAt) {
        ctx = ` \x1b[32m${bar} ${used}%\x1b[0m`;
      } else if (usedTokens <= critAt) {
        ctx = ` \x1b[33m${bar} ${used}%\x1b[0m`;
      } else {
        ctx = ` \x1b[5;31m💀 ${bar} ${used}%\x1b[0m`;
      }
    }

    // Current task from todos
    let task = '';
    const homeDir = os.homedir();
    // Respect CLAUDE_CONFIG_DIR for custom config directory setups (#870)
    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(homeDir, '.claude');
    const todosDir = path.join(claudeDir, 'todos');
    if (session && fs.existsSync(todosDir)) {
      try {
        const files = fs.readdirSync(todosDir)
          .filter(f => f.startsWith(session) && f.includes('-agent-') && f.endsWith('.json'))
          .map(f => ({ name: f, mtime: fs.statSync(path.join(todosDir, f)).mtime }))
          .sort((a, b) => b.mtime - a.mtime);

        if (files.length > 0) {
          try {
            const todos = JSON.parse(fs.readFileSync(path.join(todosDir, files[0].name), 'utf8'));
            const inProgress = todos.find(t => t.status === 'in_progress');
            if (inProgress) task = inProgress.activeForm || '';
          } catch (e) {}
        }
      } catch (e) {
        // Silently fail on file system errors - don't break statusline
      }
    }

    // PS1-style shell prefix: venv, user@host, git branch (color-coded), cwd
    const { spawnSync } = require('child_process');

    // Helper: run a command safely with an argument array (no shell injection)
    function run(cmd, args) {
      try {
        const r = spawnSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
        return (r.status === 0 && r.stdout) ? r.stdout.trim() : '';
      } catch (e) { return ''; }
    }

    let shellPrefix = '';
    try {
      // Virtual env
      const venv = process.env.VIRTUAL_ENV ? `\x1b[32m(${path.basename(process.env.VIRTUAL_ENV)}) \x1b[0m` : '';

      // user@host
      const user = run('whoami', []);
      const host = run('hostname', ['-s']);
      const userHost = `\x1b[2;37m${user}@${host}\x1b[0m`;

      // Git branch with dirty/staged state detection (read-only ops, no lock needed)
      let gitPart = '';
      const branch = run('git', ['-C', dir, 'symbolic-ref', '--short', 'HEAD'])
                  || run('git', ['-C', dir, 'rev-parse', '--short', 'HEAD']);
      if (branch) {
        const statusOut = run('git', ['-C', dir, 'status', '--porcelain']);
        const hasDirty = /^\s*[MADRCU?][MADRCU? ]/m.test(statusOut);  // unstaged / untracked
        const hasStaged = /^[MADRCU]/m.test(statusOut);                 // staged changes
        let branchColor;
        if (hasDirty) {
          branchColor = '\x1b[33m';   // yellow  — dirty  (mirrors \* in __git_ps1)
        } else if (hasStaged) {
          branchColor = '\x1b[35m';   // magenta — staged (mirrors \+ in __git_ps1)
        } else {
          branchColor = '\x1b[36m';   // cyan    — clean
        }
        gitPart = ` ${branchColor}(${branch})\x1b[0m`;
      }

      // Working directory (full path, ~ for home)
      const cwdDisplay = dir.startsWith(os.homedir()) ? '~' + dir.slice(os.homedir().length) : dir;

      shellPrefix = `${venv}${userHost}${gitPart} \x1b[2;37m${cwdDisplay}\x1b[0m \x1b[32m│\x1b[0m `;
    } catch (e) {
      // Silent fail — shell prefix is best-effort
    }

    // Output
    if (task) {
      process.stdout.write(`${shellPrefix}\x1b[2m${model}\x1b[0m │ \x1b[1m${task}\x1b[0m${ctx}`);
    } else {
      process.stdout.write(`${shellPrefix}\x1b[2m${model}\x1b[0m${ctx}`);
    }
  } catch (e) {
    // Silent fail - don't break statusline on parse errors
  }
});
