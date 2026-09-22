# Demo walkthrough

About five minutes. Commands run from this folder in a terminal (Git Bash on Windows).
Keep ChangeGuard open in the browser. Steps 3 and 4 can also run with no terminal at all,
straight from ChangeGuard's Preflight page (see "No terminal" below).

**Before the meeting** (takes about 6 minutes):

```bash
./deploy.sh cg-demo-investor
```

Wait for `DEMO READY`. Use a new name per meeting: `cg-demo-acme`, `cg-demo-20260924`.

---

**STEP 1**

```bash
kubectl get pods -n cg-demo-investor
```

SAY: "This is a small Kubernetes application I spun up for this meeting, in its own namespace."

**STEP 2**

ChangeGuard > Environments > your cluster > namespace `cg-demo-investor`.

SAY: "ChangeGuard has read-only evidence from the environment. It doesn't need permission to change
anything in order to judge a proposed change."

**STEP 3**

```bash
./evaluate.sh changes/ship.yaml
```

SAY: "We're running three replicas. I want four."

Expected: **SHIP**

SAY: "There's enough capacity for this change in this environment right now. ChangeGuard isn't just
checking whether the YAML is valid. It's judging whether this change should enter this environment
right now."

Open the printed Record link to show the judgment and its evidence in ChangeGuard.

**STEP 4**

```bash
./evaluate.sh changes/block.yaml
```

SAY: "Now the same kind of change, but scaled much further: twenty replicas."

Expected: **BLOCK**

Point at: `requests.cpu used 300m + proposed delta 1700m exceeds hard 1000m`

SAY: "The YAML is valid. Kubernetes understands it. The problem appears when you judge the change
against where it's actually going."

**Optional: HOLD**

```bash
./evaluate.sh changes/ship.yaml --no-environment
```

Expected: **HOLD**

SAY: "If ChangeGuard doesn't have enough evidence to establish that the change should ship, it
doesn't guess."

**Optional: deploy the approved change**

```bash
kubectl apply -n cg-demo-investor -f changes/ship.yaml
```

**STEP 5**

```bash
./delete.sh cg-demo-investor
```

Done.

---

If SHIP comes back HOLD with "Rollout in progress": something rolled out in the cluster in the last
five minutes, and ChangeGuard holds until it settles. Say so, show BLOCK, and try SHIP again a few
minutes later.

---

## No terminal: run SHIP and BLOCK from the Preflight page

Steps 3 and 4 also work entirely inside ChangeGuard. Open **Preflight**, type the change summary,
paste the manifest into **Manifest (YAML)**, set **Target** to your cluster, and click
**Evaluate change**.

One detail: the files in `changes/` carry no namespace (the scripts inject it), so the pasted
manifest must name your demo namespace, or the quota is judged against `default`.

Paste this for BLOCK, with summary `Scale demo-shop from 3 to 20 replicas` (used a different
namespace name? edit the `namespace:` line):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-shop
  namespace: cg-demo-investor
  labels:
    app: demo-shop
spec:
  replicas: 20   # was 3
  selector:
    matchLabels:
      app: demo-shop
  template:
    metadata:
      labels:
        app: demo-shop
    spec:
      containers:
        - name: web
          image: public.ecr.aws/nginx/nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 128Mi
```

For SHIP, paste the same block with `replicas: 4` and summary `Scale demo-shop from 3 to 4 replicas`.

Same judgment path, same quota math, and the record lands under **All changes** either way.

---

## When they compare ChangeGuard to what they already run

The two comparisons prospects reach for first, from real conversations: "we have PR/agentic
review" and "we have Terraform + Argo CD." Both get the same move: keep your stack, here is the
question it doesn't answer, and you just watched ChangeGuard answer it.

**"We already have PR review / AI review."**

SAY: "Keep it. Review evaluates the proposed change. ChangeGuard evaluates whether that change
should enter this production environment right now. You just watched it: the SHIP file and the
BLOCK file are the same kind of diff, and the verdict changed because of what is running in the
environment, not because of the YAML."

Then ask: "How do you account for the live environment when reviewing whether a change is safe
to deploy?"

**"We already have Terraform + Argo CD."**

SAY: "Keep them. Argo syncs whatever lands in git. ChangeGuard answers a question one step
earlier: should this change enter this environment right now? The BLOCK you just saw is the case
that matters: valid YAML that syncs green, and the rollout wedges at admission because the quota
isn't there. ChangeGuard returns BLOCK before the sync, with the quota math as the reason, and it
runs as a check next to Argo, advisory by default."

Both answers place ChangeGuard beside their stack, not against it. Never claim their review or
their pipeline cannot see production context; show what ChangeGuard reads and ask what theirs does.
