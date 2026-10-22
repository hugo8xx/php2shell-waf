#!/usr/bin/env bash
# Smoke-test any deployment (nginx, ModSecurity, Cloudflare, AWS, GCP).
# Sends harmless requests only — no exploit payloads.
#
# Usage: ./curl-tests.sh https://example.com [/upload/test.php]
set -uo pipefail

BASE="${1:?usage: $0 BASE_URL [UPLOAD_PATH]}"
UPLOAD="${2:-/upload/test.php}"
BLOCK_CODES="400 403 411 413 415"
fail=0

code() { curl --http1.1 -s -o /dev/null -w '%{http_code}' "$@"; }

check() {  # expect(BLOCK|PASS), label, curl args...
  local want="$1" label="$2"; shift 2
  local got; got=$(code "$@")
  local is_block=PASS
  for c in $BLOCK_CODES; do [ "$got" = "$c" ] && is_block=BLOCK; done
  if [ "$is_block" = "$want" ]; then
    printf '  ok    %-5s %-45s (%s)\n' "$want" "$label" "$got"
  else
    printf '  FAIL  want %-5s %-40s (got %s)\n' "$want" "$label" "$got"; fail=1
  fi
}

echo "Target: $BASE  upload path: $UPLOAD"
check PASS  "normal GET"                     "$BASE/"
check PASS  "urlencoded POST"                -d a=1 "$BASE/"
check PASS  "multipart to upload path"       -F a=1 "$BASE$UPLOAD"
check BLOCK "multipart to non-upload path"   -F a=1 "$BASE/index.php"
check BLOCK "chunked multipart"              -H 'Transfer-Encoding: chunked' -F a=1 "$BASE$UPLOAD"
check BLOCK "comma-variant multipart (upload path)" -H 'Content-Type: multipart/form-data,boundary=x' \
  --data-binary $'--x\r\nContent-Disposition: form-data; name="a"\r\n\r\n1\r\n--x--\r\n' "$BASE$UPLOAD"
check BLOCK "upload-progress name in query" "$BASE/?PHP_SESSION_UPLOAD_PROGRESS=1"
check BLOCK "upload-progress name in cookie" -b 'PHP_SESSION_UPLOAD_PROGRESS=x' "$BASE/"
check BLOCK "upload-progress field in body"  -F PHP_SESSION_UPLOAD_PROGRESS=x -F a=1 "$BASE$UPLOAD"
check BLOCK "11 MB body"                     --data-binary @<(head -c 11000000 /dev/zero) "$BASE$UPLOAD"

echo
echo "Note: 'field in body' is expected to FAIL on plain nginx, Cloudflare"
echo "non-Enterprise and GCP — those can't inspect body field names."
exit $fail
