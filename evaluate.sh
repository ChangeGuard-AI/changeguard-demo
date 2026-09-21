#!/usr/bin/env bash
# Ask ChangeGuard to judge a proposed change against the live demo namespace. Nothing is deployed.
#
#   ./evaluate.sh changes/ship.yaml                    judge against the namespace from the last deploy
#   ./evaluate.sh changes/block.yaml cg-demo-acme      judge against a specific namespace
#   ./evaluate.sh changes/ship.yaml --no-environment   judge with no environment evidence
#
# Calls ChangeGuard's CI judgment API, the same one a pipeline uses. Settings come from .env.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; eval "$(sed -e 's/\r$//' .env)"; set +a; fi

FILE=""; NS=""; NO_ENV=""
for a in "$@"; do
  case "$a" in
    --no-environment) NO_ENV=1 ;;
    *.yaml|*.yml) FILE="$a" ;;
    *) NS="$a" ;;
  esac
done
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "usage: ./evaluate.sh changes/ship.yaml [namespace] [--no-environment]"; exit 2
fi
[ -n "$NS" ] || NS="$(cat .namespace 2>/dev/null || true)"
[ -n "$NS" ] || { echo "Which namespace? ./evaluate.sh $FILE cg-demo-<name>   (or run ./deploy.sh first)"; exit 2; }

API="${CHANGEGUARD_API_URL:-https://api.changeguard.ai}"
APP="${CHANGEGUARD_APP_URL:-https://app.changeguard.ai}"
KEY="${CHANGEGUARD_API_KEY:-}"
if [ -z "$KEY" ] && [ -n "${CHANGEGUARD_API_KEY_AWS_SECRET:-}" ]; then
  KEY="$(aws secretsmanager get-secret-value --secret-id "$CHANGEGUARD_API_KEY_AWS_SECRET" \
        --query SecretString --output text ${AWS_REGION:+--region "$AWS_REGION"} | tr -d '\r\n')"
fi
[ -n "$KEY" ] || { echo "Set CHANGEGUARD_API_KEY in .env (ChangeGuard > Settings > API Keys, CI/CD). See .env.example."; exit 2; }
ENV_NAME="${CHANGEGUARD_ENVIRONMENT:-}"
[ -n "$NO_ENV" ] || [ -n "$ENV_NAME" ] || { echo "Set CHANGEGUARD_ENVIRONMENT in .env (the cluster's name in ChangeGuard > Environments)."; exit 2; }

esc() { sed -e 's/\r$//' -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
SUMMARY="$(sed -n 's/^# *Proposed change: *//p' "$FILE" | head -1 | esc)"
SUMMARY="${SUMMARY:-Proposed change $(basename "$FILE")}"
[ -n "$NO_ENV" ] && SUMMARY="$SUMMARY (no environment named)"
CHANGE_ID="demo-$NS-$(basename "$FILE" .yaml)${NO_ENV:+-noenv}-$(date -u +%Y%m%d-%H%M%S)"
# The files carry no namespace; the judged manifest names the demo namespace.
MANIFEST="$(awk -v ns="$NS" '{print} !d && /^metadata:/ {print "  namespace: " ns; d=1}' "$FILE" | esc | awk '{printf "%s\\n", $0}')"
TARGET=""; [ -n "$NO_ENV" ] || TARGET="\"cluster_id\":\"$ENV_NAME\","
BODY="{\"source\":\"ci\",$TARGET\"change_id\":\"$CHANGE_ID\",\"change\":{\"summary\":\"$SUMMARY\",\"manifest\":\"$MANIFEST\"}}"

RESP="$(printf '%s' "$BODY" | curl -sS -m 60 -X POST "$API/api/cicd/preflight" \
        -H "Content-Type: application/json" -H "X-API-Key: $KEY" --data-binary @-)"
VERDICT="$(printf '%s' "$RESP" | grep -oE '"verdict" *: *"[A-Z]+"' | head -1 | sed 's/.*"\([A-Z]*\)"$/\1/' || true)"
if [ -z "$VERDICT" ]; then echo "ChangeGuard did not return a judgment:"; printf '%s\n' "$RESP" | head -c 500; echo; exit 1; fi
CSC="$(printf '%s' "$RESP" | grep -oE '"csc" *: *[0-9]+' | head -1 | sed 's/.*: *//' || true)"
# Every JSON string in the response, unescaped, one per line.
STRINGS="$(printf '%s' "$RESP" | grep -oE '"([^"\\]|\\.)*"' | sed -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g' \
          -e 's/\\u003e/>/g' -e 's/\\u003c/</g' -e 's/\\u0026/\&/g' -e 's/\\u2014/\xe2\x80\x94/g' -e 's/\\\\/\\/g')"

case "$VERDICT" in SHIP) C=32 ;; HOLD) C=33 ;; *) C=31 ;; esac
echo
echo "  Change        $(sed -n 's/^# *Proposed change: *//p' "$FILE" | head -1 | tr -d '\r')"
if [ -n "$NO_ENV" ]; then echo "  Environment   none named"
else echo "  Environment   $ENV_NAME / namespace $NS"; fi
EVIDENCE="$(printf '%s\n' "$STRINGS" | grep -m1 '^Live read of the target' || true)"
[ -n "$EVIDENCE" ] && echo "  Evidence      $EVIDENCE"
echo
printf '  \033[1;%sm%s\033[0m   readiness %s/100\n\n' "$C" "$VERDICT" "${CSC:-?}"
printf '%s\n' "$STRINGS" | grep -E '^\[(CRITICAL|HIGH)\]' | sed 's/^/  x /' || true
if [ "$VERDICT" != "BLOCK" ]; then
  printf '%s\n' "$STRINGS" | grep -m1 -E '^CSC [0-9]+/100' | sed 's/^/  /' || true
  printf '%s\n' "$STRINGS" | grep -m1 -E '^No environment was named' | sed 's/^/  /' || true
fi
if printf '%s\n' "$STRINGS" | grep -q 'Rollout in progress'; then
  echo; echo "  Note: something rolled out in this cluster in the last 5 minutes; ChangeGuard holds until it settles."
fi
echo
echo "  Record: $APP/changes/$CHANGE_ID"
if [ "$VERDICT" = "SHIP" ] && [ -z "$NO_ENV" ]; then
  echo "  Deploy it (optional): kubectl apply -n $NS -f $FILE"
else
  echo "  Nothing was deployed."
fi
