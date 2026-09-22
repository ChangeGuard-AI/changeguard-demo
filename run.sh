#!/usr/bin/env bash
# The whole demo in one command.
#
#   ./run.sh            first run asks two questions, then does everything
#   ./run.sh --keep     leave the demo namespace running afterwards
#   ./run.sh --yes      no prompts (needs an existing .env), for CI
#
# What it does: deploys demo-shop into a fresh namespace, lets ChangeGuard
# observe it, asks for a judgment on a safe change (SHIP) and an unsafe one
# (BLOCK), prints both verdicts with the reasons, and deletes the namespace.
set -euo pipefail
cd "$(dirname "$0")"

KEEP=0; YES=0
for a in "$@"; do
  case "$a" in
    --keep) KEEP=1 ;;
    --yes)  YES=1 ;;
    *) echo "usage: ./run.sh [--keep] [--yes]"; exit 2 ;;
  esac
done

command -v kubectl >/dev/null || { echo "kubectl is required (and a context for a cluster connected to ChangeGuard)."; exit 2; }

if [ ! -f .env ]; then
  if [ "$YES" = 1 ]; then echo "--yes needs a .env (see .env.example)."; exit 2; fi
  echo "First run. Two questions, saved to .env (never committed):"
  printf '  ChangeGuard API key (ChangeGuard > Settings > API Keys, CI/CD scope): '
  read -rs KEY; echo
  [ -n "$KEY" ] || { echo "No key entered."; exit 2; }
  printf '  Environment name as shown in ChangeGuard > Environments: '
  read -r ENVN
  [ -n "$ENVN" ] || { echo "No environment named."; exit 2; }
  CTX="$(kubectl config current-context 2>/dev/null || true)"
  printf '  kubectl context for that cluster [%s]: ' "${CTX:-none found}"
  read -r C2; C2="${C2:-$CTX}"
  {
    echo "CHANGEGUARD_API_KEY=$KEY"
    echo "CHANGEGUARD_ENVIRONMENT=$ENVN"
    echo "KUBE_CONTEXT=$C2"
  } > .env
  chmod 600 .env 2>/dev/null || true
  echo "Saved. Next runs will not ask."
  echo
fi

NS="cg-demo-$(date +%H%M%S)"

./deploy.sh "$NS"

echo
echo "== Safe change: scale demo-shop from 3 to 4 replicas =="
./evaluate.sh changes/ship.yaml "$NS"

echo
echo "== Unsafe change: scale demo-shop from 3 to 20 replicas =="
./evaluate.sh changes/block.yaml "$NS"

echo
if [ "$KEEP" = 1 ]; then
  echo "Namespace $NS kept. Delete it later with: ./delete.sh $NS"
else
  ./delete.sh "$NS"
fi
echo
echo "Every judgment above is a record: https://app.changeguard.ai/changes"
