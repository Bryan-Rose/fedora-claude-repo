#!/usr/bin/env bash
# Runs every tests/*.test.sh; fails if any fails. Tests must be offline.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0 n=0
for t in tests/*.test.sh; do
	[[ -e $t ]] || continue
	n=$((n + 1))
	if bash "$t"; then echo "ok   $t"; else echo "FAIL $t"; fail=1; fi
done
echo "$n test file(s)"
exit "$fail"
