# ChangeGuard Demo

This repository contains a small Kubernetes workload used to demonstrate how ChangeGuard evaluates
proposed infrastructure changes against the environment they are about to enter.

## Deploy

```bash
./deploy.sh cg-demo-investor
```

Creates the namespace, deploys `demo-shop`, waits until it is healthy, and gives ChangeGuard time
to observe it (about 6 minutes). Prints `DEMO READY`.

## Baseline

`demo-shop` (nginx), 3 replicas, each requesting 100m CPU and 128Mi memory.
The namespace quota allows 1 CPU and 1Gi memory in total.

## Safe change

3 → 4 replicas ([`changes/ship.yaml`](changes/ship.yaml)): 400m of the 1 CPU budget.

```bash
./evaluate.sh changes/ship.yaml
```

Expected ChangeGuard judgment: **SHIP**

## Unsafe change

3 → 20 replicas ([`changes/block.yaml`](changes/block.yaml)): 2 CPU requested, 1 CPU available.
The YAML is valid; the namespace cannot take it.

```bash
./evaluate.sh changes/block.yaml
```

Expected ChangeGuard judgment: **BLOCK**

## Cleanup

```bash
./delete.sh cg-demo-investor
```

## Setup (once)

- `kubectl` access to a Kubernetes cluster that is connected to ChangeGuard
- bash: macOS, Linux, or Git Bash on Windows (macOS/Linux: `chmod +x *.sh` after cloning)
- `cp .env.example .env`, then add a ChangeGuard CI/CD API key and the cluster's environment name

The founder walkthrough is in [DEMO.md](DEMO.md).
