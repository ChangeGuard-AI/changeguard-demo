# ChangeGuard Demo

Watch ChangeGuard judge the same kind of change as safe or unsafe, depending on the live state
of the environment it is about to enter. Verdicts are SHIP, HOLD, or BLOCK, with the evidence
behind the call.

## Zero setup: paste it into the product

No cluster and no install needed.

1. Sign in at [app.changeguard.ai](https://app.changeguard.ai) (creating an account is free).
2. Open **Preflight** and paste the contents of [`changes/block.yaml`](changes/block.yaml)
   into **Manifest (YAML)**.
3. Click **Evaluate change**.

With no environment connected, ChangeGuard judges the change on its own and tells you exactly
which evidence it did not have. It refuses to guess: that is a HOLD, not a green checkmark.
Connect a cluster (read-only) and the same paste is judged against live state, including
whether it fits the namespace's quota.

## One command against your own cluster

```bash
git clone https://github.com/ChangeGuard-AI/changeguard-demo.git
cd changeguard-demo
./run.sh
```

The first run asks two questions (API key, environment name) and saves them to `.env`.
Then it does everything: deploys `demo-shop` (3 replicas) into a fresh namespace with a
1 CPU / 1Gi quota, waits while ChangeGuard observes it, judges a safe change and an unsafe
one, prints both verdicts, and deletes the namespace. About seven minutes, most of it
ChangeGuard watching the new workload settle.

Expected result:

- **3 → 4 replicas: SHIP.** It fits. `Deploy it (optional): kubectl apply ...`
- **3 → 20 replicas: BLOCK.** Valid YAML, but the namespace cannot take it:
  `requests.cpu used 300m + proposed delta 1700m exceeds hard 1000m`

Needs: bash (macOS, Linux, or Git Bash on Windows), `kubectl` access to a Kubernetes cluster
that is connected to ChangeGuard, and a ChangeGuard API key (Settings > API Keys, CI/CD scope).
On macOS/Linux run `chmod +x *.sh` after cloning.

## Piece by piece

| Command | What it does |
|---|---|
| `./deploy.sh cg-demo-<name>` | Create the namespace, deploy demo-shop, wait until observed |
| `./evaluate.sh changes/ship.yaml` | Judge 3 → 4 replicas. Expected: **SHIP** |
| `./evaluate.sh changes/block.yaml` | Judge 3 → 20 replicas. Expected: **BLOCK** |
| `./evaluate.sh changes/ship.yaml --no-environment` | Judge with no environment. Expected: **HOLD** |
| `./delete.sh cg-demo-<name>` | Remove the namespace and everything in it |

Nothing is ever deployed by a judgment. `evaluate.sh` calls the same API a CI pipeline calls;
the record of every judgment appears under **All changes** in ChangeGuard.

The founder walkthrough is in [DEMO.md](DEMO.md).
