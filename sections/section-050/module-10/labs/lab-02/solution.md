# Solution: Repair A Failing Liveness Probe

## Inspect the starting state

Read the pod before changing it:

```sh
kubectl -n starfleet get pods -l app=probe
kubectl -n starfleet describe pod -l app=probe
kubectl -n starfleet get deployment probe -o yaml
```

## Make the repair

Change the field responsible for this failure:

```sh
kubectl -n starfleet patch deployment probe --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"probe","livenessProbe":{"httpGet":{"port":"http"}}}]}}}}'
```

## Verify the result

Wait for the rollout, then test the Service. For a restart failure, check again after at least two liveness-probe periods.

```sh
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get pods -l app=probe
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://probe:8080/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-02
```
