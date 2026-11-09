# Restore Grafana Writable Storage

Grafana reads provisioning files but also writes a database and other state under `/var/lib/grafana`. A ConfigMap can supply configuration; it cannot provide that writable data directory. In this lab, the storage volume points at a ConfigMap and Grafana cannot start.

Use this lab's independent environment for the commands below. It runs Grafana in `telemetry`; the module playground uses `monitoring`.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-020-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-02
```

## Trace the mount to its volume

Read the events before assuming the process has crashed:

```sh
kubectl -n telemetry describe pod -l app=grafana
kubectl -n telemetry get deployment grafana -o json | jq '.spec.template.spec | {securityContext, volumes, mounts: .containers[0].volumeMounts}'
```

A missing ConfigMap prevents mounting before the container starts. Creating it would resolve that lookup, but the mounted files would still be read-only. Follow `volumeMounts[].name` to the matching entry in `volumes`. The mount at `/var/lib/grafana` must refer to writable storage.

For this disposable exercise, replace only the `grafana-storage` volume source with `emptyDir`. Save this strategic merge patch as `grafana-storage.yaml`:

```yaml
spec:
  template:
    spec:
      volumes:
        - name: grafana-storage
          configMap: null
          emptyDir: {}
```

Apply the patch and wait for the replacement pod:

```sh
kubectl -n telemetry patch deployment grafana --type=strategic --patch-file grafana-storage.yaml
kubectl -n telemetry rollout status deployment/grafana --timeout=180s
kubectl get --raw /api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health
```

The pod's user and group settings remain unchanged. The configured `fsGroup` gives the Grafana process access to the volume. Do not run Grafana as root to compensate for the wrong volume source.

An `emptyDir` survives a container restart in the same pod, but it disappears when the pod is replaced. Provisioning restores the supplied data source after replacement. A production installation that must retain database changes needs persistent storage.

Forward Grafana in another terminal, then test authenticated access:

```sh
kubectl -n telemetry port-forward svc/grafana 3300:3000
```

```sh
curl -s -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/org
```

Expect HTTP `200`. Readiness and a successful login prove that the process both started and can use its data directory.

## Common pitfalls

> [!WARNING]
> - A ConfigMap mount is read-only even if the files are called database files.
> - Keep the provisioning mount separate from the writable data mount.
> - Container restart and pod replacement have different effects on `emptyDir` data.

## Your mission: Restore Grafana Writable Storage

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Use the lab started above.

Submit after verifying the result:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-02
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-020-01-02
astrona start ats-020-playground-020-01
```
