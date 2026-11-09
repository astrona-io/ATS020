# Solution: Repair Grafana Secret Keys

## Inspect the starting state

```sh
kubectl -n telemetry get pods -l app=grafana
kubectl -n telemetry describe pod -l app=grafana
kubectl -n telemetry get deployment grafana -o yaml
kubectl -n telemetry get secret grafana-admin -o json | jq '.data | keys'
```

## Make the repair

Add the key the existing environment variable reads. Keep the older key as well:

Save this as `secret-grafana-admin.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin
  namespace: telemetry
type: Opaque
stringData:
  admin-password: starfleet
  password: starfleet
```

Apply it:

```sh
kubectl apply -f secret-grafana-admin.yaml
```

## Verify the result

```sh
kubectl -n telemetry rollout status deployment/grafana --timeout=180s
kubectl get --raw /api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health
kubectl -n telemetry port-forward svc/grafana 3300:3000
```

In another terminal, expect HTTP status `200`:

```sh
curl -s -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/org
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-10/labs/lab-04
```
