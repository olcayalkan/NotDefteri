#!/usr/bin/env bash
# Fails the job when CodeQL reports a security finding of medium severity or higher
# (security-severity >= 4.0, GitHub's medium/high/critical bands) or any error-level result.
# Low-severity and code-quality findings stay visible in the summary without blocking.
set -euo pipefail

dir=$1
threshold=${CODEQL_GATE_THRESHOLD:-4.0}

shopt -s nullglob
files=("$dir"/*.sarif)
if (( ${#files[@]} == 0 )); then
  echo "::error::No SARIF output: the analysis did not finish, so the code cannot be cleared."
  exit 1
fi

blocking=$(jq -r --argjson esik "$threshold" '
  .runs[]
  | ([.tool.driver.rules[]?, .tool.extensions[]?.rules[]?]
     | map({key: .id, value: (.properties["security-severity"] // "0" | tonumber)})
     | from_entries) as $severity
  | .results[]?
  | select(.baselineState != "absent" and (.suppressions // [] | length) == 0)
  | ($severity[.ruleId] // 0) as $s
  | select($s >= $esik or .level == "error")
  | (.locations[0].physicalLocation // {}) as $loc
  | "\($loc.artifactLocation.uri // "?"):\($loc.region.startLine // 0)  \(.ruleId)  severity=\($s)  \(.message.text | gsub("[\r\n]+"; " "))"
' "${files[@]}")

if [[ -n $blocking ]]; then
  count=$(printf '%s\n' "$blocking" | wc -l | tr -d ' ')
  echo "::error::$count blocking CodeQL finding(s) (security-severity >= $threshold or level error):"
  printf '%s\n' "$blocking"
  exit 1
fi
echo "No blocking CodeQL findings (security-severity >= $threshold or level error)."
