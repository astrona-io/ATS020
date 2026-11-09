# Size Grafana Memory For Startup

Grafana can need more memory during startup than a small steady-state sample suggests. This lab supplies valid storage and credentials but sets the memory limit too low for startup. Read the termination reason before changing resource settings.

Use this lab's independent environment for the commands below. It runs Grafana in `telemetry`; the module playground uses `monitoring`.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-020-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-05
```

## Distinguish termination from configuration failure

```sh
kubectl -n telemetry describe pod -l app=grafana
kubectl -n telemetry get pods -l app=grafana -o json | jq '.items[].status.containerStatuses[] | {name, state, lastState, restartCount}'
kubectl -n telemetry get deployment grafana -o json | jq '.spec.template.spec.containers[].resources'
```

Look for `OOMKilled` in the current or previous terminated state. Exit code `137` alone only establishes that the process received `SIGKILL`; pair it with the reason and the configured memory limit.

A request reserves capacity for scheduling. A limit constrains the container's memory use. Raising the request alone does not raise the limit. In this fixture, `128Mi` requested and `512Mi` limited allow Grafana to start:

```sh
kubectl -n telemetry set resources deployment/grafana --requests=memory=128Mi --limits=memory=512Mi
kubectl -n telemetry rollout status deployment/grafana --timeout=180s
kubectl -n telemetry get pods -l app=grafana
```

The pod template change creates a replacement. Inspect that current pod rather than a terminating pod from the old ReplicaSet. Check the restart count again after startup and confirm the API responds:

```sh
kubectl get --raw /api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health
kubectl -n telemetry port-forward svc/grafana 3300:3000
```

In another terminal:

```sh
curl -s -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/org
```

Expect HTTP `200`. Keep the finite limit, image, storage and account settings. These values are suitable for this fixture; sizing another deployment requires measurements of its startup and normal workload.

## Common pitfalls

> [!WARNING]
> - Removing the limit hides the resource-sizing decision.
> - An old terminating pod can still show the failure after its replacement succeeds.
> - Readiness once is not proof of stability; check for new restarts after startup.

## Your mission: Size Grafana Memory For Startup

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Use the lab started above.

Submit after verifying the result:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-05
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-020-01-05
astrona start ats-020-playground-020-01
```
