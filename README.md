# changeguard-demo

A small web service, `demo-shop`, running in the `cg-demo` namespace. Two
replicas of nginx behind a Service, with a namespace budget that is easy to
exceed on purpose.

This repository is deliberately boring. The sophistication belongs in
ChangeGuard, not here.

## What's in it

```
base/namespace.yaml       the cg-demo namespace
base/resourcequota.yaml   500m CPU, 512Mi memory, 6 pods
base/deployment.yaml      demo-shop, 2 replicas, 100m CPU + 64Mi each
base/service.yaml         demo-shop on port 80
```

These describe what is actually running. That matters more than it sounds: a
judgment about a proposed change is only as good as the match between what the
repository claims and what the cluster has.

## Proposing a change

Edit `base/deployment.yaml` in a pull request. That is the whole workflow —
there is no ChangeGuard-specific step, no script to run, and nothing to paste.

`.github/workflows/changeguard.yml` calls ChangeGuard on every pull request. It
reads the manifests the pull request touches, judges the proposed object against
the live `cg-demo` namespace, and posts the verdict as a check.

### Two changes worth trying

**`replicas: 2` → `3`** — 300m CPU against a 500m budget. It fits, and nothing
about the environment argues against it.

**`replicas: 2` → `20`** — 2,000m CPU against a 500m budget, and 20 pods
against a limit of 6. This one cannot work, and it is worth being precise about
why: ChangeGuard is not expressing a preference. It is arithmetic against the
ResourceQuota in this repository, which is why the answer is the same every
time.

A change that fits the budget is not thereby *safe*; it is *feasible*. Those are
different claims, and ChangeGuard makes the one it can support.

## Applying it yourself

```
kubectl apply -f base/
```

The manifests name their own namespace, so there is nothing to pass on the
command line and no way to apply them somewhere you did not mean to.
