#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product proposal-demo
bin_dir="$(swift build --show-bin-path)"
"$bin_dir/proposal-demo" Examples/checklist.json
"$bin_dir/proposal-demo" Examples/invitation.json
set +e
output="$("$bin_dir/proposal-demo" Examples/invalid-outcome.json 2>&1)"
status=$?
set -e
if [[ "$status" -ne 1 || "$output" != "Rejected: invalidCandidate" ]]; then
  printf 'Unexpected invalid-outcome result: exit %s; %s\n' "$status" "$output" >&2
  exit 1
fi
printf '%s\n' "$output" "All three example expectations passed."
