#!/usr/bin/env bash
set -euo pipefail

# Run the test suite inside docker-compose (db + app)

# Prefer `docker compose`, fall back to legacy `docker-compose`
if docker compose version >/dev/null 2>&1; then
  compose_cmd=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
else
  echo "docker compose (or docker-compose) not found; please install Docker Compose." >&2
  exit 1
fi

"${compose_cmd[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
"${compose_cmd[@]}" up --build --abort-on-container-exit --exit-code-from app
