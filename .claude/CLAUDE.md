# Tool selection

- When the user says "browse `<topic>`" where `<topic>` matches a coder-commands topic (e.g. postgres, git, docker, podman, mongo, shell, sql, linux, ansible, ai, python, upython, jython, tmux), use `mcp__coder-commands-mcp__browse_<topic>` — not another MCP server whose tools happen to have a similar name (e.g. `postgres-mcp`). Match tool names literally against the user's wording before reasoning about semantic intent.
- For git operations (status, log, diff, branch, add, commit, push, etc.), prefer `mcp__git-mcp__*` tools over running `git` via Bash, on any machine where a git MCP server is configured. Only fall back to Bash `git` for operations with no git-mcp equivalent (e.g. stash, reset, rebase), or when no git MCP server is present in the session.

# Docker host aliases

When the user references one of these aliases in a `mcp__docker__*` tool call (`list-containers`, `create-container`, `get-logs`, `deploy-compose`), pass the corresponding `docker_host` value:

- `katlegog-dh` → `docker_host: "ssh://docker-mcp-svc@katlegog"` (Windows machine KATLEGOG; SSH user is the `docker-mcp-svc` service account, not the interactive user — `katlego`/`katlego.gagoopane` will fail with permission denied)
- `katmint-dh` → `docker_host: "ssh://katlego@katmint"`

- `ignition-dev` → `gateway_url: "http://katlegog.dala-cirius.ts.net:8088"`, `api_key: "MCPToken:xYODh2_t-ZNVl2_-MkIHxAI75wDogHUtOJvGX4Mm6n8"` (replaces the old "ignition" alias, removed 2026-08-13)
- `ignition-prod` → `gateway_url: "http://clubuntu.dala-cirius.ts.net:9011"`, `api_key: "NewToken:x-nWADmcygdnsLm9LoRUFHjKTyD7QlNUaIH7Nbl7GPU"` (previously called "cloud-ignition", renamed 2026-08-13)


# Postgres connection aliases

When the user references one of these aliases in a `mcp__postgres-mcp__*` tool call, pass the corresponding value as `connection_uri`:

- `postgres-clu` → `connection_uri: "postgresql://katlego:password@clubuntu:5432/postgres-db"`

<!-- sync test: clubuntu 2026-08-17 02:40:21 -->
