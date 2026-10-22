#!/usr/bin/env bash
# Add the PHP2Shell rules to a zone's custom WAF rules (non-destructive:
# existing custom rules are kept; new rules are appended).
#
# Usage:
#   CF_API_TOKEN=... CF_ZONE_ID=... CF_PLAN=free|pro|business|enterprise ./deploy.sh
# Token needs: Zone > Zone WAF > Edit.
set -euo pipefail

: "${CF_API_TOKEN:?set CF_API_TOKEN}"
: "${CF_ZONE_ID:?set CF_ZONE_ID}"
CF_PLAN="${CF_PLAN:-free}"
API="https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/rulesets"
DIR="$(cd "$(dirname "$0")" && pwd)"

case "$CF_PLAN" in
  free|pro)   levels='["free"]' ;;
  business)   levels='["free","business"]' ;;
  enterprise) levels='["free","business","enterprise"]' ;;
  *) echo "CF_PLAN must be free|pro|business|enterprise" >&2; exit 1 ;;
esac

rules=$(jq --argjson l "$levels" '[.[] | select(.min_plan as $p | $l | index($p)) | del(.min_plan)]' "$DIR/rules.json")

cf() { curl -sS -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" "$@"; }

entry=$(cf "$API/phases/http_request_firewall_custom/entrypoint")
if [ "$(echo "$entry" | jq -r .success)" != "true" ]; then
  # No custom ruleset yet -> create it with our rules.
  echo "Creating custom rules entrypoint..."
  cf -X PUT "$API/phases/http_request_firewall_custom/entrypoint" \
    --data "$(jq -n --argjson r "$rules" '{rules: $r}')" | jq '{success, errors}'
  exit 0
fi

rid=$(echo "$entry" | jq -r .result.id)
echo "$rules" | jq -c '.[]' | while read -r rule; do
  desc=$(echo "$rule" | jq -r .description)
  if echo "$entry" | jq -e --arg d "$desc" '.result.rules // [] | any(.description == $d)' >/dev/null; then
    echo "skip (exists): $desc"; continue
  fi
  echo "add: $desc"
  cf -X POST "$API/$rid/rules" --data "$rule" | jq -c '{success, errors}'
done
