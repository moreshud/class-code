#!/usr/bin/env bash
# Run before pushing/sharing class5 — fails if instructor secrets appear in tracked files.
set -euo pipefail

CLASS5_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CLASS5_ROOT"

FAIL=0

if git rev-parse --is-inside-work-tree &>/dev/null; then
  if git ls-files --error-unmatch class5/.env &>/dev/null 2>&1; then
    echo "FAIL: class5/.env is tracked by git — run: git rm --cached class5/.env" >&2
    FAIL=1
  fi
fi

if [[ -f "$CLASS5_ROOT/.env" ]]; then
  echo "OK: .env exists locally (gitignored — not shared)"
else
  echo "NOTE: no .env — students copy .env.example"
fi

PATTERNS=(
  '129\.153\.93\.80'
  'id_ed25519_lambda'
  'hf_[a-zA-Z0-9]{20,}'
  'BEGIN OPENSSH PRIVATE KEY'
)

SCAN_FILES=(
  LAMBDA.md COMMANDS.md Readme.md .env.example class5.ipynb
  scripts/lambda_check.sh scripts/lambda_jupyter.sh scripts/lambda_pdf_deps.sh
  scripts/lambda_setup.sh scripts/sync_to_lambda.sh scripts/export_notebook.sh
  lib/*.py agent_demo.py requirements.txt
)

for pat in "${PATTERNS[@]}"; do
  hits=$(grep -REl "$pat" "${SCAN_FILES[@]}" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    grep -REn "$pat" $hits 2>/dev/null || true
    echo "FAIL: pattern '$pat' found in shareable files above" >&2
    FAIL=1
  fi
done

if [[ "$FAIL" -eq 0 ]]; then
  echo "OK: no obvious secrets in class5 shareable files"
else
  exit 1
fi
