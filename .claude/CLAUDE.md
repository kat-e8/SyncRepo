# Tool selection

- When the user says "browse `<topic>`" where `<topic>` matches a coder-commands topic (e.g. postgres, git, docker, podman, mongo, shell, sql, linux, ansible, ai, python, upython, jython, tmux), use `mcp__coder-commands-mcp__browse_<topic>` — not another MCP server whose tools happen to have a similar name (e.g. `postgres-mcp`). Match tool names literally against the user's wording before reasoning about semantic intent.
- For git operations (status, log, diff, branch, add, commit, push, etc.), prefer `mcp__git-mcp__*` tools over running `git` via Bash, on any machine where a git MCP server is configured. Only fall back to Bash `git` for operations with no git-mcp equivalent (e.g. stash, reset, rebase), or when no git MCP server is present in the session.
<!-- watcher test 2 (fixed) -->
<!-- watcher test 3 -->
<!-- watcher test 4 (debug) -->
