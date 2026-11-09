# Solution: Repair A Crashing Process

## Inspect the starting state

```sh
kubectl -n starfleet describe pod -l app=beacon
kubectl -n starfleet logs deploy/beacon --previous
kubectl -n starfleet get deployment beacon -o yaml
```

## Make the repair

```sh
kubectl -n starfleet patch deployment beacon --type=merge -p '{"spec":{"template":{"spec":{"containers":[{"name":"beacon","image":"ghcr.io/stefanprodan/podinfo:6.17.0","ports":[{"name":"http","containerPort":9898}],"resources":{"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"128Mi"}}}]}}}}'
```

## Verify the result

```sh
kubectl -n starfleet rollout status deployment/beacon --timeout=180s
kubectl -n starfleet exec deploy/shuttle -- curl -s -o /dev/null -w '%{http_code}\n' http://beacon:9898/
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-10/labs/lab-05
```
