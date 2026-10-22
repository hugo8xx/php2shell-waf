#!/usr/bin/env bash
# Apache mod_php 8.3.35 (vulnerable) behind each defensive layer:
#   A :18101  Apache mod_rewrite + php_admin_flag (local-vps/apache)
#   B :18102  ModSecurity v2, our rules only, LimitAction Reject
#   C :18103  ModSecurity v2, our rules only, LimitAction ProcessPartial
#   D :18104  ModSecurity v2, our rules only, NoFilesLimit 13 MB
# Sends the shared curl tests plus PoC-shaped requests (no exploit payload).
#
# Usage: ./tests/apache/run.sh   (KEEP=1 to leave containers running)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
fail=0

# shellcheck disable=SC2329  # invoked via trap
cleanup() {
  [ "${KEEP:-0}" = "1" ] && return
  (cd "$HERE" && docker compose down >/dev/null 2>&1)
}
trap cleanup EXIT

echo "### building + starting (PHP 8.3.35, Apache, ModSecurity v2)"
(cd "$HERE" && docker compose build -q rewrite && docker compose up -d --force-recreate >/dev/null 2>&1) \
  || { echo "compose failed"; exit 1; }
sleep 5

echo; echo "### layer A: session.upload_progress must be off via php_admin_flag"
if curl -s localhost:18101/index.php | grep -q '"session.upload_progress.enabled":"0"'; then
  echo "  ok    upload progress disabled"
else
  echo "  FAIL  upload progress still enabled"; fail=1
fi

for p in 18101 18102; do
  echo; echo "### curl tests :$p"
  out=$("$ROOT/tests/curl-tests.sh" "http://localhost:$p" | grep -E '^  (ok|FAIL) '); echo "$out"
  if [ "$p" = 18101 ]; then
    echo "  (body-field FAIL is expected on layer A — mod_rewrite can't read bodies)"
    echo "$out" | grep 'FAIL' | grep -qv 'field in body' && fail=1
  else
    echo "$out" | grep -q 'FAIL' && fail=1
  fi
done

echo; echo "### PoC-shaped requests"
python3 -I "$HERE/poc_shape.py" 'http://localhost:18101#nobody' \
  http://localhost:18102 http://localhost:18103 http://localhost:18104 || fail=1

echo; [ $fail = 0 ] && echo "ALL OK" || echo "SOME CHECKS FAILED"
exit $fail
