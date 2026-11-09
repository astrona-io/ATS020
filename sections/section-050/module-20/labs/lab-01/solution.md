# Solution: Repair A Webhook Service Port

## Inspect the starting state

Use the API error to locate the failing component.

```sh
kubectl -n starfleet create deployment lab-check --image=ghcr.io/stefanprodan/podinfo:6.17.0
```

```sh
kubectl -n webhook-system get service starfleet-policy -o yaml
kubectl -n webhook-system get deployment starfleet-policy -o yaml
```

## Make the repair

Save this as `service-starfleet-policy.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: starfleet-policy
  namespace: webhook-system
spec:
  selector:
    app: starfleet-policy
  ports:
  - port: 443
    targetPort: 8443
```

Apply it:

```sh
kubectl apply -f service-starfleet-policy.yaml
```

## Verify the result

A successful create and a new server log entry prove admission works:

```sh
kubectl -n starfleet create deployment lab-check --image=ghcr.io/stefanprodan/podinfo:6.17.0
kubectl -n webhook-system logs deploy/starfleet-policy --tail=10
kubectl -n starfleet delete deployment lab-check
```

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-050/module-20/labs/lab-01
```
