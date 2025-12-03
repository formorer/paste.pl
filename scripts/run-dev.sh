#!/usr/bin/env bash
set -euo pipefail

# Spin up app + db for manual testing on http://localhost:3000

# Prefer docker compose v2, fall back to docker-compose
if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo "docker compose (or docker-compose) not found; please install Docker Compose." >&2
  exit 1
fi

# Build and start in detached mode
"${compose_cmd[@]}" up --build -d db app_dev

echo "Manual test instance should be reachable at http://localhost:3000 (once db/app_dev are healthy)."
