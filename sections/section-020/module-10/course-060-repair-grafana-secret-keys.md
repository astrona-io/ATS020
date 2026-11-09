# Repair Grafana Secret Keys

Grafana's pod template reads the key `admin-password` from Secret `grafana-admin`. The Secret in `telemetry` contains only `password`. A Secret with the same name in `monitoring` does not satisfy a pod in another namespace.

Use this lab's independent environment for the commands below. It runs Grafana in `telemetry`; the module playground uses `monitoring`.

<!-- astrona:playground:renew -->

```sh
astrona stop ats-020-playground-020-01
astrona run --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-10/labs/lab-04
```

## Compare the reference with the available keys

The kubelet resolves `secretKeyRef` before starting the container. A missing key therefore appears in pod events, often with `CreateContainerConfigError`, rather than in Grafana's application log.

```sh
kubectl -n telemetry describe pod -l app=grafana
kubectl -n telemetry get deployment grafana -o json | jq '.spec.template.spec.containers[0].env'
kubectl -n telemetry get secret grafana-admin -o json | jq '.data | keys'
```

Inspect key names without printing secret values. Match the namespace, Secret name and key from the pod template. Keep the environment variable `GF_SECURITY_ADMIN_PASSWORD` and its existing reference unchanged.

Add the missing key to the Secret. These are public exercise credentials. Save this as `grafana-admin.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: telemetry
type: Opaque
stringData:
  password: starfleet
  admin-password: starfleet
```

Apply it and watch the waiting pod start:

```sh
kubectl apply -f grafana-admin.yaml
kubectl -n telemetry rollout status deployment/grafana --timeout=180s
kubectl get --raw /api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health
```

A container that could not start retries its configuration. A container already running with an environment variable does not receive later Secret changes automatically; it needs replacement to read a new value. Grafana also keeps its initialized admin account in its database, so changing the startup password setting is not a general password-reset procedure.

Forward Grafana and test the supplied account:

```sh
kubectl -n telemetry port-forward svc/grafana 3300:3000
```

```sh
curl -s -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/org
```

Expect HTTP `200`. The lab's writable storage and memory settings already work; the missing key is the only repair.

## Common pitfalls

> [!WARNING]
> - Secrets are namespaced; matching names in different namespaces are different objects.
> - Base64 encoding is not encryption. Avoid exposing real secret values while debugging.
> - Preserve the older key when another consumer might still use it.

## Your mission: Repair Grafana Secret Keys

Grafana was moved to `telemetry`. One startup fault remains; the other settings already allow it to run. The Service `grafana` listens on port `3000`.

This independent lab has 4 tasks. Allow 10–15 minutes for task work, plus environment startup and telemetry collection.

Use the lab started above.

Submit after verifying the result:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-04
```

Remove the lab and resume the playground:

```sh
astrona destroy ats-020-lab-020-01-04
astrona start ats-020-playground-020-01
```
