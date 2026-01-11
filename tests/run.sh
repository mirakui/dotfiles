#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0

for t in "${ROOT_DIR}/tests/"*_test.sh; do
  if [[ ! -f "$t" ]]; then
    continue
  fi
  echo "RUN  $t"
  if bash "$t"; then
    echo "PASS $t"
  else
    echo "FAIL $t" >&2
    failures=$((failures + 1))
  fi
done

if [[ $failures -ne 0 ]]; then
  echo "${failures} test(s) failed" >&2
  exit 1
fi

echo "All tests passed"
