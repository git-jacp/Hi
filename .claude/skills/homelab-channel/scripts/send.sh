#!/usr/bin/env bash
# Sends one message to the homelab bridge webhook and prints only the HTTP
# status code and response body. Never use -i/-v/-D here: the edge may set
# a Set-Cookie (Cloudflare Access session) that must never land in a
# transcript or log.
set -euo pipefail

ENDPOINT="${HOMELAB_CHANNEL_URL:-https://2ed00c.elcarri.es/v1/messages}"
TYPE="${1:?usage: send.sh <type> <ref> <text>}"
REF="${2:?usage: send.sh <type> <ref> <text>}"
TEXT="${3:?usage: send.sh <type> <ref> <text>}"

TMP_BODY="$(mktemp)"
trap 'rm -f "$TMP_BODY"' EXIT

PAYLOAD="$(python3 -c '
import json, sys
print(json.dumps({"type": sys.argv[1], "ref": sys.argv[2], "text": sys.argv[3]}))
' "$TYPE" "$REF" "$TEXT")"

HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w '%{http_code}' -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")"

echo "HTTP_CODE=$HTTP_CODE"
cat "$TMP_BODY"
echo
