#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# setup-dev-venv.sh — Create a single .venv for all services
#
# Run from repo root:
#   bash local/setup-dev-venv.sh
#   # or:
#   make local-setup
# ──────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"

# Use python3.12 if available, fall back to python3
if command -v python3.12 &>/dev/null; then
  PYTHON=python3.12
else
  PYTHON=python3
fi

echo ">>> Using: $($PYTHON --version)"

# ── 1. Create venv (skip if already exists) ──────────────────
if [[ -d "$VENV_DIR" ]]; then
  echo ">>> venv exists at $VENV_DIR — skipping creation, updating packages"
else
  echo ">>> Creating Python venv at $VENV_DIR"
  $PYTHON -m venv "$VENV_DIR"
fi

# ── 2. Upgrade pip ────────────────────────────────────────────
echo ">>> Upgrading pip"
"$VENV_DIR/bin/pip" install --upgrade pip -q

# ── 3. Install/update unified requirements ────────────────────
echo ">>> Installing/updating .dev/requirements-dev.txt"
"$VENV_DIR/bin/pip" install -r "$REPO_ROOT/.dev/requirements-dev.txt" -q

# ── 4. Install/update smp-common as editable package ─────────
# Note: 'workflow' extra skipped — it pulls pygraphviz which needs gcc+graphviz
# headers (only needed for state-machine diagram generation, not service runtime).
echo ">>> Installing smp-common (editable, kafka+grpc+db+taskiq)"
"$VENV_DIR/bin/pip" install -e "$REPO_ROOT/smp-common[kafka,grpc,db,taskiq]" -q

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Done!  Interpreter: $VENV_DIR/bin/python"
echo ""
echo "  VS Code: Ctrl+Shift+P → Python: Select Interpreter"
echo "           choose .venv/bin/python (Recommended)"
echo ""
echo "  Start infra first: make local-infra-d"
echo "  Then press F5 in VS Code to debug any service."
echo "════════════════════════════════════════════════════════"
