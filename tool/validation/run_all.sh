#!/usr/bin/env bash
#
# Every validation that can run without network, in one command.
#
#   bash tool/validation/run_all.sh
#
# Writes docs/VALIDATION_REPORT.md from scratch each time, so the report in
# the repo is always reproducible from the data in the repo.
#
# Re-fetching the source series (Binance, Yahoo) is deliberately NOT here:
# it needs network, the providers rate-limit, and the redistribution terms
# for the bundled data are still unverified (docs/DATA_SOURCES.md). Those
# checks belong in a job someone runs knowingly.

set -euo pipefail
cd "$(dirname "$0")/../.."

PY="${PYTHON:-python}"

echo "==> Level integrity, crash windows, pause points, optimal moves"
"$PY" tool/validation/validate_levels.py

echo "==> Discipline Score: baselines and 10,000 random runs per level"
"$PY" tool/validation/score_baselines.py

echo
echo "==> Wrote docs/VALIDATION_REPORT.md"
