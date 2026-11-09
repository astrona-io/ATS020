# Solution: Repair An Image Reference

## Inspect the starting state

Read the pod before changing it:

```sh
kubectl -n starfleet get pods -l app=beacon
kubectl -n starfleet describe pod -l app=beacon
kubectl -n starfleet get deployment beacon -o yaml
```

## Make the repair

Change the field responsible for this failure:

```sh
kubectl -n starfleet set image deployment/beacon beacon=ghcr.io/stefanprodan/podinfo:6.17.0
```

## Verify the result

Wait for the rollout, then test the Service. For a restart failure, check again after at least two liveness-probe periods.

```sh
kubectl -n starfleet rollout status deployment/beacon --timeout=180s
kubectl -n starfleet get pods -l app=beacon
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://beacon:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-04
```
