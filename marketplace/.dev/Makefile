# ══════════════════════════════════════════════════════════════
# .dev/Makefile — Local dev additions ONLY
#
# Includes the root Makefile so every existing target works
# unchanged. Overrides migrate-* and test-* to run via the
# local .venv instead of Docker images (which aren't built yet).
#
# Usage (from repo root):
#   make -f .dev/Makefile setup          # create .venv
#   make -f .dev/Makefile infra-reset    # first time: wipe + seed DB
#   make -f .dev/Makefile services-d     # subsequent: start infra
#   make -f .dev/Makefile migrate-all    # alembic via local .venv
#   make -f .dev/Makefile seed-admin     # seed admin user (auth-service)
#   make -f .dev/Makefile seed-application  # seed service categories (application-service)
#   make -f .dev/Makefile seed-all       # seed all services
#   make -f .dev/Makefile test-auth      # pytest via local .venv
# ══════════════════════════════════════════════════════════════

SHELL   := /bin/bash
DEV_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO    := $(abspath $(DEV_DIR)/..)
VENV    := $(REPO)/.venv/bin

# Inherit ALL targets from the root Makefile
include $(REPO)/Makefile

# Override SERVICES — adds Kafka host-listener on localhost:9094
SERVICES = -p smp-infra \
           -f $(REPO)/devops/docker-compose.services.yml \
           -f $(DEV_DIR)docker-compose.dev-local.yml

# ── Setup / DB ────────────────────────────────────────────────

setup: ## Create/update .venv with all service deps
	bash $(DEV_DIR)setup-dev-venv.sh

init-db: ## Create the 5 service databases in running postgres (idempotent)
	@for db in auth_db application_db documents_db payments_db notifications_db; do \
	  docker exec smp-db psql -U smp_user -d smp_db -tc \
	    "SELECT 1 FROM pg_database WHERE datname='$$db'" | grep -q 1 \
	  && echo "EXISTS  $$db" \
	  || (docker exec smp-db psql -U smp_user -d smp_db -c "CREATE DATABASE $$db" \
	      && echo "CREATED $$db"); \
	done

infra-reset: ## Wipe data volumes, restart infra, seed databases
	$(MAKE) -f $(DEV_DIR)Makefile services-down
	sudo chown -R $(USER):$(USER) $(REPO)/devops/data
	rm -rf $(REPO)/devops/data/pg-data $(REPO)/devops/data/es-data
	mkdir -p $(REPO)/devops/data/pg-data $(REPO)/devops/data/es-data
	$(MAKE) -f $(DEV_DIR)Makefile services-d
	@echo "Waiting for postgres..." && \
	  until docker exec smp-db psql -U smp_user -d smp_db -c "SELECT 1" \
	    >/dev/null 2>&1; do sleep 1; done
	$(MAKE) -f $(DEV_DIR)Makefile init-db

# ── Migrations (local .venv, not Docker images) ───────────────

migrate-auth: ## alembic upgrade heads — auth-service
	cd $(REPO)/services/auth-service && \
	  set -a && source $(DEV_DIR).env.auth && set +a && \
	  PYTHONPATH=$(REPO)/services/auth-service $(VENV)/python -m alembic upgrade heads

migrate-application: ## alembic upgrade heads — application-service
	cd $(REPO)/services/application-service && \
	  set -a && source $(DEV_DIR).env.application && set +a && \
	  PYTHONPATH=$(REPO)/services/application-service $(VENV)/python -m alembic upgrade heads

migrate-docs: ## alembic upgrade heads — documents-service
	cd $(REPO)/services/documents-service && \
	  set -a && source $(DEV_DIR).env.documents && set +a && \
	  PYTHONPATH=$(REPO)/services/documents-service $(VENV)/python -m alembic upgrade heads

migrate-pay: ## alembic upgrade heads — payments-service
	cd $(REPO)/services/payments-service && \
	  set -a && source $(DEV_DIR).env.payments && set +a && \
	  PYTHONPATH=$(REPO)/services/payments-service $(VENV)/python -m alembic upgrade heads

migrate-notif: ## alembic upgrade heads — notifications-service
	cd $(REPO)/services/notifications-service && \
	  set -a && source $(DEV_DIR).env.notifications && set +a && \
	  PYTHONPATH=$(REPO)/services/notifications-service $(VENV)/python -m alembic upgrade heads

migrate-all: migrate-auth migrate-application migrate-docs migrate-pay migrate-notif ## Run all migrations

# ── Seeding (local .venv) ─────────────────────────────────────

seed-admin: ## Seed initial admin user — auth-service
	cd $(REPO)/services/auth-service && \
	  set -a && source $(DEV_DIR).env.auth && set +a && \
	  PYTHONPATH=$(REPO)/services/auth-service $(VENV)/python -m app.cli.seed_admin

seed-application: ## Seed initial service categories — application-service
	cd $(REPO)/services/application-service && \
	  set -a && source $(DEV_DIR).env.application && set +a && \
	  PYTHONPATH=$(REPO)/services/application-service $(VENV)/python -m app.cli.seed_admin_data

seed-all: seed-admin seed-application ## Seed all services

# ── Tests (local .venv) ───────────────────────────────────────

test-auth: ## pytest — auth-service
	cd $(REPO)/services/auth-service && \
	  set -a && source $(DEV_DIR).env.auth && set +a && \
	  PYTHONPATH=$(REPO)/services/auth-service $(VENV)/pytest -v

test-application: ## pytest — application-service
	cd $(REPO)/services/application-service && \
	  set -a && source $(DEV_DIR).env.application && set +a && \
	  PYTHONPATH=$(REPO)/services/application-service $(VENV)/pytest -v

test-docs: ## pytest — documents-service
	cd $(REPO)/services/documents-service && \
	  set -a && source $(DEV_DIR).env.documents && set +a && \
	  PYTHONPATH=$(REPO)/services/documents-service $(VENV)/pytest -v

test-pay: ## pytest — payments-service
	cd $(REPO)/services/payments-service && \
	  set -a && source $(DEV_DIR).env.payments && set +a && \
	  PYTHONPATH=$(REPO)/services/payments-service $(VENV)/pytest -v

test-notif: ## pytest — notifications-service
	cd $(REPO)/services/notifications-service && \
	  set -a && source $(DEV_DIR).env.notifications && set +a && \
	  PYTHONPATH=$(REPO)/services/notifications-service $(VENV)/pytest -v

test-all: test-auth test-application test-docs test-pay test-notif ## Run all tests
