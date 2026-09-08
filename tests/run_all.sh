#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tests/test_version.sh
bash tests/test_bash_colour_testcard.sh
echo "PASS: all bash-colour-testcard tests"
