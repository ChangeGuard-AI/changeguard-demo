# Proposed changes

Each file is `base/deployment.yaml` with one line changed.

| File | Change | CPU requested after | Namespace budget | Expected judgment |
|---|---|---|---|---|
| `ship.yaml` | replicas 3 → 4 | 400m | 1 CPU | **SHIP** |
| `block.yaml` | replicas 3 → 20 | 2 CPU | 1 CPU | **BLOCK** |

Judge a change (nothing is deployed):

```bash
./evaluate.sh changes/ship.yaml
./evaluate.sh changes/block.yaml
```

Deploy the approved change (optional):

```bash
kubectl apply -n cg-demo-investor -f changes/ship.yaml
```
