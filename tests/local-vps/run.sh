#!/usr/bin/env bash
# End-to-end test of local-vps/ against real nginx + PHP-FPM (+ ModSecurity).
#
# Usage:
#   ./tests/local-vps/run.sh                 # PHP 8.3 (latest patch)
#   PHP_VERSION=8.3.35 ./tests/local-vps/run.sh   # a vulnerable build
#   KEEP=1 ./tests/local-vps/run.sh          # leave containers running
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PORT="${PORT:-18090}"; MSC_PORT="${MSC_PORT:-18091}"
export PORT
fail=0

# shellcheck disable=SC2329  # invoked via trap
cleanup() {
  [ "${KEEP:-0}" = "1" ] && return
  docker rm -f php2shell-msc >/dev/null 2>&1
  (cd "$HERE" && docker compose down -v >/dev/null 2>&1)
}
trap cleanup EXIT

echo "### starting nginx + PHP-FPM ${PHP_VERSION:-8.3}"
(cd "$HERE" && docker compose up -d --force-recreate --quiet-pull >/dev/null 2>&1) || { echo "compose up failed"; exit 1; }
docker rm -f php2shell-msc >/dev/null 2>&1
docker run -d --name php2shell-msc -p "$MSC_PORT:8080" \
  -e BACKEND="http://host.docker.internal:$PORT" -e MODSEC_RULE_ENGINE=On -e BLOCKING_PARANOIA=1 \
  -v "$ROOT/local-vps/modsecurity/php2shell.conf:/opt/owasp-crs/rules/ZZ-php2shell.conf:ro" \
  owasp/modsecurity-crs:nginx >/dev/null
sleep 8

echo; echo "### effective PHP-FPM settings"
curl -s "localhost:$PORT/index.php"
curl -s "localhost:$PORT/index.php" | grep -q '"session.upload_progress.enabled":"0"' \
  || { echo "  FAIL  session.upload_progress.enabled is not 0"; fail=1; }

results() { "$ROOT/tests/curl-tests.sh" "$1" | grep -E '^  (ok|FAIL) '; }

echo; echo "### nginx -> PHP-FPM"
out=$(results "http://localhost:$PORT"); echo "$out"
echo "  (body-field FAIL is expected on plain nginx — php.ini covers it)"
echo "$out" | grep 'FAIL' | grep -qv 'field in body' && fail=1

echo; echo "### ModSecurity -> nginx -> PHP-FPM"
out=$(results "http://localhost:$MSC_PORT"); echo "$out"
echo "$out" | grep -q 'FAIL' && fail=1

echo; echo "### legit upload reaches PHP"
up=$(curl -s -F note=hi -F "doc=@$ROOT/README.md" "localhost:$PORT/upload/test.php")
echo "  $up"; echo "$up" | grep -q '"error":0' || { echo "  FAIL upload"; fail=1; }

echo; echo "### OOM -> nginx error log -> fail2ban filter"
for _ in 1 2 3; do curl -s -o /dev/null "localhost:$PORT/oom.php"; done
log="$(mktemp)"
(cd "$HERE" && docker compose logs --no-log-prefix nginx 2>/dev/null) | grep 'Allowed memory' > "$log"
docker run --rm -v "$ROOT/local-vps/fail2ban:/f:ro" -v "$log:/e.log:ro" --entrypoint fail2ban-regex \
  crazymax/fail2ban:latest /e.log /f/filter.d/php2shell.conf 2>&1 | grep '^Lines:' | tee /dev/stderr | grep -q ' 3 matched' \
  || { echo "  FAIL fail2ban did not match 3 OOM lines"; fail=1; }
rm -f "$log"

echo; echo "### oversized PHPSESSID response is logged"
curl -s -o /dev/null "localhost:$PORT/leak.php"
if (cd "$HERE" && docker compose exec -T nginx cat /var/log/nginx/php2shell.log 2>/dev/null) | grep -q 'leak.php'; then
  echo "  ok    leak.php flagged in php2shell.log"
else
  echo "  FAIL leak not logged"; fail=1
fi

echo; [ $fail = 0 ] && echo "ALL OK" || echo "SOME CHECKS FAILED"
exit $fail
