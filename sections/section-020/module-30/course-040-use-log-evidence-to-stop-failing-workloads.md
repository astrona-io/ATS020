# Use Log Evidence To Stop Failing Workloads

Loki can identify pods producing errors, but Kubernetes controllers own their replica counts. Follow each matching pod's owner references before acting. This exercise intentionally stops the failing test workloads; a production response also depends on the service's availability requirements.

The playground uses StatefulSet `depot`; the independent lab uses StatefulSet `cargo`. Read owner references rather than assuming a controller name from a pod prefix.

Forward Loki in a separate terminal:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/loki 3100:3100
```

## Find the owners and verify the result


Ask Loki which Pods write error lines:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [5m]))' |
  jq -r '.data.result[] | "\(.metric.pod) \(.value[1])"'
```

Look for `probe` Pods, whose names have generated endings, and the Pod `depot-0`. A Pod does not scale, so find what owns each one:

```sh
kubectl -n outpost get pods \
  -o custom-columns='POD:.metadata.name,KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
kubectl -n outpost get replicasets \
  -o custom-columns='REPLICASET:.metadata.name,KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
```

Look for two kinds of owner. `depot-0` belongs directly to the StatefulSet `depot`. A `probe` Pod belongs to a ReplicaSet, and that ReplicaSet belongs to the Deployment `probe`. Scale the two controllers to `0`:

```sh
kubectl -n outpost scale deployment probe --replicas=0
kubectl -n outpost scale statefulset depot --replicas=0
```

Then check the result:

```sh
kubectl -n outpost get deployments,statefulsets
```

Look for `probe` and `depot` with `0` Pods, while `beacon` and `scout` still run. Run the Loki query again after five minutes and look for an empty result. You went from a log query to a change on the exact controllers that needed it.


## Common pitfalls

> [!WARNING]
> - Deleting a managed pod makes its controller create another one.
> - Keep healthy controllers running.
> - Old error lines remain in a range query until its lookback window expires.
> - A mention of an error is not necessarily an error event; inspect the selected lines.

## Your mission: Find And Stop Error-Logging Workloads

Loki stores logs with `namespace`, `pod` and `container` labels. Grafana has the editable `loki` data source and the saved `outpost-logs` dashboard.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Pause the playground and start the lab:

```sh
astrona stop ats-020-playground-020-03
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-30/labs/lab-02
```

Submit after verifying the result:

```sh
astrona submit -c sections/section-020/module-30/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-020-03-02
astrona start ats-020-playground-020-03
```
