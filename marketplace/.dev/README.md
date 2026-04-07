# .dev — Local Host-Side Dev Environment

**Not tracked by git.** Registered in `.git/info/exclude`.  
Never modify `.gitignore`, `Makefile`, or any other tracked file for local dev — put everything here instead.

## What's here

| File | Purpose |
|------|---------|
| `Makefile` | All local dev commands — use instead of root Makefile |
| `setup-dev-venv.sh` | Creates `.venv` at repo root with all 5 services' deps merged |
| `requirements-dev.txt` | Merged/deduplicated deps for all services + `debugpy` |
| `docker-compose.dev-local.yml` | Adds Kafka `PLAINTEXT_HOST` listener on `localhost:9094` |
| `.env.auth` … `.env.notifications` | Per-service env vars pointing at `localhost` infra |

## Services & ports

| Service | HTTP | debugpy |
|---------|------|---------|
| auth-service | 8000 | — |
| application-service | 8001 | — |
| documents-service | 8002 | — |
| payments-service | 8003 | — |
| notifications-service | 8004 | — |

gRPC (auth): `50051`  
Kafka host listener: `localhost:9094` (Docker internal stays `smp-kafka:9092`)

## First-time setup

```bash
make -f .dev/Makefile setup        # create .venv, install everything
make -f .dev/Makefile infra-d      # start PG + Redis + Kafka + ES in Docker
make -f .dev/Makefile migrate-all  # alembic upgrade heads for all services
# seed admin user if needed:
make -f .dev/Makefile seed-admin
```

Then **F5** in VS Code → pick a service or **"All Services (debug, no reload)"**.

## VS Code

`.vscode/` is also gitignored. Configs already present:
- `settings.json` — interpreter = `.venv/bin/python`, Pylance paths for all services
- `launch.json` — debug config per service (breakpoints) + reload variants + taskiq worker/scheduler + compound launchers
- `tasks.json` — setup, infra, migrate, test tasks via `Ctrl+Shift+P → Tasks: Run Task`

## Key decisions

- **Single `.venv`** at repo root — one interpreter for all 5 services, smp-common installed editable
- **`workflow` extra excluded** from smp-common install (pulls `pygraphviz` which needs system gcc/graphviz — not needed at runtime)
- **Kafka dual-listener** — services on host use `localhost:9094`; Docker containers use `smp-kafka:9092`
- **No `--reload`** in debug configs — uvicorn reload forks a child process, breaking debugpy breakpoints
