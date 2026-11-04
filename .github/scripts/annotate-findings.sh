#!/usr/bin/env bash
# Turns compiler and test log errors/warnings into GitHub annotations.
# Annotations appear on the run page and on the matching line in the PR's "Files changed"
# tab, so the failing stage and location are found without reading the whole log.
set -uo pipefail

log=$1
stage=$2
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}
root=${GITHUB_WORKSPACE:-$PWD}
repo=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}
sha=${GITHUB_SHA:-HEAD}

[[ -s $log ]] || exit 0

# The same warning can be printed for several targets; annotate each location once.
findings=$(grep -E '^/[^:]+\.swift:[0-9]+(:[0-9]+)?: (error|warning): ' "$log" | sort -u)
[[ -n $findings ]] || exit 0

# Escape characters that break workflow command syntax.
escape() { local s=${1//%/%25}; s=${s//$'\r'/%0D}; printf '%s' "${s//$'\n'/%0A}"; }

errors=0
warnings=0
rows=""
while IFS= read -r line; do
  [[ $line =~ ^(/[^:]+\.swift):([0-9]+)(:([0-9]+))?:\ (error|warning):\ (.*)$ ]] || continue
  file=${BASH_REMATCH[1]#"$root"/}
  number=${BASH_REMATCH[2]}
  column=${BASH_REMATCH[4]}
  kind=${BASH_REMATCH[5]}
  message=${BASH_REMATCH[6]}

  echo "::$kind file=$file,line=$number${column:+,col=$column},title=$stage::$(escape "$message")"

  if [[ $kind == error ]]; then errors=$((errors + 1)); icon="❌"; else warnings=$((warnings + 1)); icon="⚠️"; fi
  rows+="| $icon | [\`$file:$number\`]($repo/blob/$sha/$file#L$number) | ${message//|/\\|} |"$'\n'
done <<< "$findings"

{
  printf '### %s: %d errors, %d warnings\n\n' "$stage" "$errors" "$warnings"
  printf '| | Location | Message |\n|---|---|---|\n'
  printf '%s' "$rows" | head -50
  [[ $((errors + warnings)) -gt 50 ]] && printf '\nShowing the first 50 findings; see the job log for all.\n'
  printf '\n'
} >> "$summary"
exit 0
