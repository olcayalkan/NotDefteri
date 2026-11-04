#!/usr/bin/env bash
# Writes the CodeQL findings from the SARIF output to the run page and the job log.
set -uo pipefail

dir=$1
title=$2
summary=${GITHUB_STEP_SUMMARY:-/dev/null}

shopt -s nullglob
files=("$dir"/*.sarif)

{
  printf '### %s\n\n' "$title"
  if (( ${#files[@]} == 0 )); then
    printf 'No SARIF output: the analysis did not finish.\n'
    exit 0
  fi
  count=$(jq -s '[.[].runs[].results[]?] | length' "${files[@]}")
  printf '**%s finding(s)**\n\n' "$count"
  if (( count > 0 )); then
    printf '| Level | Rule | Location | Message |\n|---|---|---|---|\n'
    jq -r '.runs[].results[]?
      | (.locations[0].physicalLocation // {}) as $loc
      | "| \(.level // "warning") | `\(.ruleId)` | `\($loc.artifactLocation.uri // "?"):\($loc.region.startLine // 0)` | \(.message.text | gsub("[\r\n]+"; " ") | gsub("\\|"; "\\|")) |"' \
      "${files[@]}" | head -100
    (( count > 100 )) && printf '\nShowing the first 100 findings; see the Security tab for all.\n'
  fi
} | tee -a "$summary"
