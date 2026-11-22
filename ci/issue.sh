#!/usr/bin/env bash
# One rolling issue per label, owned by the workflow bot (design D9/D12).
# Usage: ci/issue.sh open  <label> <title> <body-file>   # create or update
#        ci/issue.sh close <label> <comment>             # close if open
# Env: GH_TOKEN, GH_REPO
set -euo pipefail
cmd=$1 label=$2

# Only issues the bot opened count, so a look-alike from anyone else is ignored.
num=$(gh issue list --label "$label" --author 'app/github-actions' --state open \
	--json number --jq '.[0].number // empty')

case $cmd in
open)
	title=$3 body=$4
	gh label create "$label" --color B60205 --force >/dev/null
	if [[ -n $num ]]; then
		gh issue edit "$num" --title "$title" --body-file "$body" >/dev/null
		gh issue comment "$num" --body "Still happening: $(date -u +%FT%TZ). See the issue body for the latest details." >/dev/null
		echo "Updated issue #$num"
	else
		gh issue create --label "$label" --title "$title" --body-file "$body"
	fi
	;;
close)
	[[ -z $num ]] || { gh issue close "$num" --comment "$3" >/dev/null; echo "Closed issue #$num"; }
	;;
*) echo "unknown command $cmd" >&2; exit 2 ;;
esac
