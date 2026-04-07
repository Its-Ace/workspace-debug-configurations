#!/usr/bin/env bash
# Ensure all core infra Docker containers are running.
# Starts them via make if any are stopped, then waits for Postgres.
set -euo pipefail

CONTAINERS=(smp-db smp-redis smp-kafka smp-elasticsearch)
RUNNING=$(docker inspect -f '{{.State.Running}}' "${CONTAINERS[@]}" 2>/dev/null | grep -c '^true$' || true)

if [ "$RUNNING" -eq 4 ]; then
  echo "Infra already up (4/4 containers running)"
else
  echo "Starting infra ($RUNNING/4 containers running)..."
  make -f .dev/Makefile services-d
  echo "Waiting for postgres..."
  until docker exec smp-db psql -U smp_user -d smp_db -c "SELECT 1" >/dev/null 2>&1; do
    sleep 1
  done
  echo "Postgres ready."
fi
