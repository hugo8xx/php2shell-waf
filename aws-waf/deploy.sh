#!/usr/bin/env bash
# Create the PHP2Shell rule group in AWS WAFv2.
#
# Usage:
#   SCOPE=REGIONAL AWS_REGION=ap-southeast-1 ./deploy.sh      # ALB / API GW
#   SCOPE=CLOUDFRONT ./deploy.sh                               # CloudFront (us-east-1)
#   MODE=count ...                                             # dry-run: Count instead of Block
#
# Then attach it to your Web ACL (console or update-web-acl) as a
# RuleGroupReferenceStatement, BEFORE the AWS managed rule groups.
set -euo pipefail

SCOPE="${SCOPE:-REGIONAL}"
MODE="${MODE:-block}"
NAME="${NAME:-php2shell-cve-2026-109618-109619}"
DIR="$(cd "$(dirname "$0")" && pwd)"
[ "$SCOPE" = "CLOUDFRONT" ] && export AWS_REGION=us-east-1

rules_file="$(mktemp)"; trap 'rm -f "$rules_file"' EXIT
if [ "$MODE" = "count" ]; then
  jq '[.[] | .Action = {"Count": {}}]' "$DIR/rules.json" > "$rules_file"
else
  cp "$DIR/rules.json" "$rules_file"
fi

wcu=$(aws wafv2 check-capacity --scope "$SCOPE" --rules "file://$rules_file" --query Capacity --output text)
cap=$((wcu + 50))   # capacity is immutable — leave headroom for edits
echo "Rules need $wcu WCU; creating rule group with capacity $cap"

aws wafv2 create-rule-group \
  --name "$NAME" \
  --scope "$SCOPE" \
  --capacity "$cap" \
  --description "Virtual patch for PHP2Shell (CVE-2026-109618 / CVE-2026-109619)" \
  --rules "file://$rules_file" \
  --visibility-config "SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=${NAME}" \
  --query Summary.ARN --output text
