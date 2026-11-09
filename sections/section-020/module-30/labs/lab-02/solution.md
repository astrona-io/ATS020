# Solution: Find And Stop Error-Logging Workloads

## Inspect the starting state

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

Use Grafana Explore to run `{namespace="outpost"} |= "ERROR"`. Inspect the Pod labels of returned log streams.

## Make the repair

The seeded errors come from `probe` and `cargo`. Verify both in Loki before stopping their controllers:

```sh
kubectl -n outpost get pods -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name
kubectl -n outpost get replicasets -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name
kubectl -n outpost scale deployment/probe statefulset/cargo --replicas=0
```

## Verify the result

```sh
kubectl -n outpost get deployment,statefulset,pods
kubectl -n starfleet get deployment
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-30/labs/lab-02
```
