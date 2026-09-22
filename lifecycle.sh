#!/usr/bin/env bash
# The full change lifecycle, for real, in one command:
#
#   bash lifecycle.sh              uses the namespace from the last deploy.sh
#   bash lifecycle.sh cg-demo-x    uses a specific namespace
#
# 1. ChangeGuard judges the change (3 -> 4 replicas) against the live namespace.
# 2. If the verdict is SHIP, YOUR kubectl applies it (ChangeGuard never writes).
# 3. The rollout is watched to completion.
# 4. The outcome is reported against the same verdict, by id, never by timing.
# Open the printed record: proposed, judged, deployed, outcome, one screen.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; eval "$(sed -e 's/\r$//' .env)"; set +a; fi

NS="${1:-$(cat .namespace 2>/dev/null || true)}"
[ -n "$NS" ] || { echo "Which namespace? bash lifecycle.sh cg-demo-<name>   (or run deploy.sh first)"; exit 2; }
KC=(kubectl); [ -n "${KUBE_CONTEXT:-}" ] && KC+=(--context "$KUBE_CONTEXT")

API="${CHANGEGUARD_API_URL:-https://api.changeguard.ai}"
APP="${CHANGEGUARD_APP_URL:-https://app.changeguard.ai}"
KEY="${CHANGEGUARD_API_KEY:-}"
if [ -z "$KEY" ] && [ -n "${CHANGEGUARD_API_KEY_AWS_SECRET:-}" ]; then
  KEY="$(aws secretsmanager get-secret-value --secret-id "$CHANGEGUARD_API_KEY_AWS_SECRET" \
        --query SecretString --output text ${AWS_REGION:+--region "$AWS_REGION"} | tr -d '\r\n')"
fi
[ -n "$KEY" ] || { echo "Set CHANGEGUARD_API_KEY in .env (see .env.example)."; exit 2; }
ENV_NAME="${CHANGEGUARD_ENVIRONMENT:-}"
[ -n "$ENV_NAME" ] || { echo "Set CHANGEGUARD_ENVIRONMENT in .env."; exit 2; }

FILE=changes/ship.yaml
esc() { sed -e 's/\r$//' -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
SUMMARY="$(sed -n 's/^# *Proposed change: *//p' "$FILE" | head -1 | esc)"
CHANGE_ID="demo-$NS-lifecycle-$(date -u +%Y%m%d-%H%M%S)"
MANIFEST="$(awk -v ns="$NS" '{print} !d && /^metadata:/ {print "  namespace: " ns; d=1}' "$FILE" | esc | awk '{printf "%s\\n", $0}')"
BODY="{\"source\":\"ci\",\"cluster_id\":\"$ENV_NAME\",\"change_id\":\"$CHANGE_ID\",\"change\":{\"summary\":\"$SUMMARY\",\"manifest\":\"$MANIFEST\"}}"

echo "1/4  Asking ChangeGuard to judge: $SUMMARY (namespace $NS)"
RESP="$(printf '%s' "$BODY" | curl -sS -m 60 -X POST "$API/api/cicd/preflight" \
        -H "Content-Type: application/json" -H "X-API-Key: $KEY" --data-binary @-)"
VERDICT="$(printf '%s' "$RESP" | grep -oE '"verdict" *: *"[A-Z]+"' | head -1 | sed 's/.*"\([A-Z]*\)"$/\1/' || true)"
VERDICT_ID="$(printf '%s' "$RESP" | grep -oE '"verdict_id" *: *"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
[ -n "$VERDICT" ] || { echo "ChangeGuard did not return a judgment:"; printf '%s\n' "$RESP" | head -c 400; echo; exit 1; }

if [ "$VERDICT" != "SHIP" ]; then
  echo "     Verdict: $VERDICT. Nothing will be deployed."
  if printf '%s' "$RESP" | grep -q 'Rollout in progress'; then
    echo "     Something rolled out in this cluster in the last 5 minutes; ChangeGuard holds until it settles."
    echo "     Try again in a few minutes."
  fi
  echo "     Record: $APP/changes/$CHANGE_ID"
  exit 0
fi
echo "     Verdict: SHIP (verdict $VERDICT_ID)"

echo "2/4  Deploying it with YOUR kubectl (ChangeGuard has no write access)"
"${KC[@]}" -n "$NS" apply -f "$FILE" >/dev/null

echo "3/4  Watching the rollout"
"${KC[@]}" -n "$NS" rollout status deployment/demo-shop --timeout=120s >/dev/null
echo "     demo-shop is at 4 replicas"

echo "4/4  Reporting the outcome against that same verdict"
OUT="{\"verdict_id\":\"$VERDICT_ID\",\"cluster_id\":\"$ENV_NAME\",\"outcome\":\"success\",\"detected_by\":\"human\",\"workload\":\"demo-shop\",\"namespace\":\"$NS\"}"
ORESP="$(printf '%s' "$OUT" | curl -sS -m 60 -X POST "$API/api/cicd/outcome" \
        -H "Content-Type: application/json" -H "X-API-Key: $KEY" --data-binary @-)"
printf '%s' "$ORESP" | grep -oE '"message" *: *"([^"\\]|\\.)*"' | head -1 | sed -e 's/^"message" *: *"//' -e 's/"$//' -e 's/\\"/"/g' -e 's/^/     /' || true

echo
echo "Open the record: $APP/changes/$CHANGE_ID"
echo "Judged before the change, deployed by you, outcome attached to the same record."
echo
echo "Reset for another pass: kubectl scale deployment/demo-shop -n $NS --replicas=3 ${KUBE_CONTEXT:+--context $KUBE_CONTEXT}"
