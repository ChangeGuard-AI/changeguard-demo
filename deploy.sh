#!/usr/bin/env bash
# Deploy the demo workload into a fresh namespace.
#
#   ./deploy.sh cg-demo-investor
#
# Creates the namespace, the quota and demo-shop (3 replicas), waits until it is healthy,
# then gives ChangeGuard time to observe it. Uses kubectl's current context, or KUBE_CONTEXT from .env.
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; eval "$(sed -e 's/\r$//' .env)"; set +a; fi

NS="${1:-}"
if ! [[ "$NS" =~ ^cg-demo-[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || [ ${#NS} -gt 63 ]; then
  echo "usage: ./deploy.sh cg-demo-<name>     e.g. ./deploy.sh cg-demo-investor"
  exit 2
fi
KC=(kubectl); [ -n "${KUBE_CONTEXT:-}" ] && KC+=(--context "$KUBE_CONTEXT")

echo "Cluster:   ${KUBE_CONTEXT:-$(kubectl config current-context)}"
echo "Namespace: $NS"
if "${KC[@]}" get namespace "$NS" >/dev/null 2>&1; then
  echo "Namespace $NS already exists. Choose another name, or run ./delete.sh $NS first."
  exit 1
fi

sed "s/NAMESPACE/$NS/" base/namespace.yaml | "${KC[@]}" apply -f - >/dev/null
"${KC[@]}" -n "$NS" apply -f base/resourcequota.yaml -f base/deployment.yaml -f base/service.yaml >/dev/null
echo "Deploying demo-shop (3 replicas)..."
"${KC[@]}" -n "$NS" rollout status deployment/demo-shop --timeout=180s >/dev/null
printf '%s\n' "$NS" > .namespace
echo
"${KC[@]}" -n "$NS" get pods -l app=demo-shop
echo
"${KC[@]}" -n "$NS" describe resourcequota demo-quota | sed -n '/^Resource/,$p'
echo

# ChangeGuard treats a rollout anywhere in the cluster during the last five minutes as still
# in progress, and holds changes until it settles. Give it that long to see a settled workload.
S=${SETTLE_SECONDS:-330}
echo "Letting ChangeGuard observe the new workload (about $(( (S + 59) / 60 )) minutes)."
echo "Meanwhile: ChangeGuard > Environments > your cluster > namespace $NS shows it within a minute."
while [ "$S" -gt 0 ]; do printf '\r  %d:%02d ' $((S / 60)) $((S % 60)); sleep 10; S=$((S - 10)); done
printf '\r          \r'
echo
echo "DEMO READY"
echo "Namespace: $NS"
