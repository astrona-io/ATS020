# Solution: Schedule A Pending Workload

## Inspect the starting state

Read the pod before changing it:

```sh
kubectl -n starfleet get pods -l app=scout
kubectl -n starfleet describe pod -l app=scout
kubectl -n starfleet get deployment scout -o yaml
```

## Make the repair

Change the field responsible for this failure:

```sh
kubectl -n starfleet patch deployment scout --type=merge -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'
```

## Verify the result

Wait for the rollout, then test the Service. For a restart failure, check again after at least two liveness-probe periods.

```sh
kubectl -n starfleet rollout status deployment/scout --timeout=180s
kubectl -n starfleet get pods -l app=scout
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://scout:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-01
```
