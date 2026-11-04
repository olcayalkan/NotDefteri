#!/usr/bin/env bash
# Writes a summary table from the test log to the run page, so the number of tests run
# and the failing ones are visible without opening the log.
set -uo pipefail

log=$1
platform=$2
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}

if [[ ! -s $log ]]; then
  printf '### %s\n\nTests did not run: the build or an earlier step failed.\n' "$platform" >> "$summary"
  exit 0
fi

# XCTest prints one line per suite; the total follows the "All tests" line.
total_line=$(grep -A1 "Test Suite 'All tests'" "$log" | grep -E "Executed [0-9]+ tests?" | tail -1)
ran=$(sed -nE 's/.*Executed ([0-9]+) tests?.*/\1/p' <<< "$total_line")
failed=$(sed -nE 's/.* with ([0-9]+) failures?.*/\1/p' <<< "$total_line")
duration=$(sed -nE 's/.* in ([0-9.]+) .*/\1/p' <<< "$total_line")

if [[ -z $ran ]]; then
  status="⚠️ Test process was interrupted (crash or timeout)"
elif [[ ${failed:-0} -eq 0 ]]; then
  status="✅ Passed"
else
  status="❌ Failing tests"
fi

{
  printf '### %s\n\n' "$platform"
  printf '| Status | Ran | Failed | Duration |\n|---|---|---|---|\n'
  printf '| %s | %s | %s | %s s |\n\n' "$status" "${ran:--}" "${failed:--}" "${duration:--}"

  failures=$(grep -E "error: .*(failed|XCT)" "$log" | sed -E 's#^.*/([^/]+\.swift:[0-9]+): error: #\1: #' | head -30)
  if [[ -n $failures ]]; then
    printf '<details><summary>Failing tests</summary>\n\n```\n%s\n```\n\n</details>\n' "$failures"
  fi
} >> "$summary"
