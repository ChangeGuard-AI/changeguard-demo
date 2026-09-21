#!/usr/bin/env bash
# Delete a demo namespace created by deploy.sh (and everything in it).
#
#   ./delete.sh cg-demo-investor
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .env ]; then set -a; eval "$(sed -e 's/\r$//' .env)"; set +a; fi

NS="${1:-}"
[[ "$NS" =~ ^cg-demo- ]] || { echo "usage: ./delete.sh cg-demo-<name>"; exit 2; }
KC=(kubectl); [ -n "${KUBE_CONTEXT:-}" ] && KC+=(--context "$KUBE_CONTEXT")

if ! "${KC[@]}" get namespace "$NS" >/dev/null 2>&1; then
  echo "Namespace $NS does not exist."; exit 0
fi
PART="$("${KC[@]}" get namespace "$NS" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')"
if [ "$PART" != "changeguard-demo" ]; then
  echo "Refusing: $NS was not created by deploy.sh."; exit 1
fi

echo "Deleting namespace $NS..."
"${KC[@]}" delete namespace "$NS" --wait=true >/dev/null
if [ "$(cat .namespace 2>/dev/null || true)" = "$NS" ]; then rm -f .namespace; fi
echo "Done. Namespace $NS is gone."
