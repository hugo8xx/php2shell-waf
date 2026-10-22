#!/usr/bin/env bash
# Add PHP2Shell rules to an existing Cloud Armor security policy.
#
# Usage:
#   POLICY=my-policy ./deploy.sh              # enforce
#   POLICY=my-policy PREVIEW=1 ./deploy.sh    # preview mode (log only)
#   PRIORITY_BASE=1000 ...                    # change if 1000-1003 are taken
#
# Cloud Armor custom rules can't match on the request body, so the
# body-field checks from the other platforms aren't possible here —
# disable session.upload_progress in php.ini (see local-vps/php).
set -euo pipefail

: "${POLICY:?set POLICY (Cloud Armor security policy name)}"
BASE="${PRIORITY_BASE:-1000}"
PREVIEW_FLAG=""; [ "${PREVIEW:-0}" = "1" ] && PREVIEW_FLAG="--preview"

# TODO: replace with your application's real upload endpoints.
UPLOAD_PATHS="request.path.startsWith('/upload') || request.path.startsWith('/wp-admin/async-upload.php') || request.path.startsWith('/wp-admin/media-new.php')"
MULTIPART="has(request.headers['content-type']) && request.headers['content-type'].lower().contains('multipart/')"

add() {  # priority, description, expression
  echo "add $1: $2"
  gcloud compute security-policies rules create "$1" \
    --security-policy="$POLICY" \
    --description="$2" \
    --expression="$3" \
    --action=deny-403 $PREVIEW_FLAG
}

add $((BASE + 0)) "PHP2Shell: multipart to non-upload path (CVE-2026-109618/109619)" \
  "$MULTIPART && !($UPLOAD_PATHS)"

add $((BASE + 1)) "PHP2Shell: multipart without Content-Length or chunked (CVE-2026-109618)" \
  "$MULTIPART && (!has(request.headers['content-length']) || (has(request.headers['transfer-encoding']) && request.headers['transfer-encoding'].lower().contains('chunked')))"

add $((BASE + 2)) "PHP2Shell: session upload progress name in query/cookie (CVE-2026-109619)" \
  "request.query.lower().contains('php_session_upload_progress') || (has(request.headers['cookie']) && request.headers['cookie'].lower().contains('php_session_upload_progress'))"

add $((BASE + 3)) "PHP2Shell: declared body >= 10 MB (CVE-2026-109618)" \
  "has(request.headers['content-length']) && request.headers['content-length'].matches('^[0-9]{8,}$')"
