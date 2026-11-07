# Solution

| Check | Step |
| --- | --- |
| `grafana-ready` | Steps 2, 3 and 4 |
| `login-works` | Step 3 |
| `only-allowed-changes` | Steps 2, 3 and 4 |

## The feedback loop

Open a separate terminal and start the grader in watch mode. It re-grades every few seconds, does not record an attempt and does not delete the lab:

```sh
astrona submit --watch --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/labs/lab-02
```

Leave it running and read which checks turn green after each step. Keep the plain `astrona submit` for the very end, because a plain submit is final and removes the lab.

## Step 1: Read the Pod

Start with the Pod's status and events. The events name the fault that stops the Pod right now:

```sh
kubectl -n telemetry get pods -l app=grafana
kubectl -n telemetry describe pod -l app=grafana | tail -n 12
```

```text
NAME                       READY   STATUS              RESTARTS   AGE
grafana-7c9d8b6f4d-x2k9p   0/1     ContainerCreating   0          3m
...
  Warning  FailedMount  12s (x9 over 3m)  kubelet  MountVolume.SetUp failed for volume "grafana-storage" : configmap "grafana-storage" not found
```

`ContainerCreating` means the kubelet cannot start the container yet. The event says why: the volume `grafana-storage` is a ConfigMap volume, and no ConfigMap of that name exists in `telemetry`. Look at the volume in the Deployment:

```sh
kubectl -n telemetry get deployment grafana -o jsonpath='{.spec.template.spec.volumes}' | jq
```

```json
[
  { "name": "grafana-storage", "configMap": { "name": "grafana-storage" } },
  { "name": "datasources", "configMap": { "name": "grafana-datasources" } }
]
```

The volume is mounted at `/var/lib/grafana`. That is Grafana's data directory, where it writes its SQLite database. A ConfigMap is read-only, so even an existing ConfigMap would not work here. Grafana needs a volume it can write to.

## Step 2: Give Grafana a writable data directory

Replace the ConfigMap volume with an `emptyDir`. An `emptyDir` is an empty directory the kubelet creates for the Pod and removes with it. Open the Deployment in your editor:

```sh
kubectl -n telemetry edit deployment grafana
```

Change the volume `grafana-storage` under `spec.template.spec.volumes` from this:

```yaml
      - name: grafana-storage
        configMap:
          name: grafana-storage
```

to this:

```yaml
      - name: grafana-storage
        emptyDir: {}
```

Save and close. If you prefer one command, a strategic merge patch finds the volume by its name. The `null` removes the `configMap` field:

```sh
kubectl -n telemetry patch deployment grafana --type=strategic -p '{
  "spec": {"template": {"spec": {"volumes": [
    {"name": "grafana-storage", "configMap": null, "emptyDir": {}}
  ]}}}
}'
```

The Deployment uses the `Recreate` strategy, so the old Pod stops and a new one starts. Read the new Pod:

```sh
kubectl -n telemetry get pods -l app=grafana
kubectl -n telemetry describe pod -l app=grafana | tail -n 6
```

```text
NAME                       READY   STATUS                       RESTARTS   AGE
grafana-5f6b7c8d9e-q4w7z   0/1     CreateContainerConfigError   0          20s
...
  Warning  Failed  4s (x3 over 18s)  kubelet  Error: couldn't find key admin-password in Secret telemetry/grafana-admin
```

The volume mounts now. The next fault shows: `CreateContainerConfigError`. The kubelet builds the container's environment and cannot find the key `admin-password` in the Secret `grafana-admin`.

## Step 3: Add the missing Secret key

Compare the two Secrets. The one left in `monitoring` has the key the container reads; the new one in `telemetry` does not:

```sh
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data}' | jq 'keys'
kubectl -n telemetry get secret grafana-admin -o jsonpath='{.data}' | jq 'keys'
```

```text
["admin-password", "admin-user"]
["password"]
```

The environment variable `GF_SECURITY_ADMIN_PASSWORD` reads the key `admin-password`. You may not rename the environment variable, so give the Secret that key. Recreate the Secret with both keys, so nothing that reads `password` breaks:

```sh
kubectl -n telemetry create secret generic grafana-admin \
  --from-literal=admin-password=starfleet \
  --from-literal=password=starfleet \
  --dry-run=client -o yaml | kubectl apply -f -
```

The kubelet retries the container with the new Secret on its own. Watch the Pod:

```sh
kubectl -n telemetry get pods -l app=grafana -w
```

```text
NAME                       READY   STATUS      RESTARTS      AGE
grafana-5f6b7c8d9e-q4w7z   0/1     OOMKilled   2 (25s ago)   1m
grafana-5f6b7c8d9e-q4w7z   0/1     CrashLoopBackOff   2 (30s ago)   1m
```

Stop the watch with `Ctrl+C`. The container now starts, but the kernel kills it: `OOMKilled` means the container used more memory than its limit allows. Read the limit:

```sh
kubectl -n telemetry get deployment grafana -o jsonpath='{.spec.template.spec.containers[0].resources}' | jq
```

```json
{
  "limits": { "memory": "32Mi" },
  "requests": { "cpu": "50m", "memory": "32Mi" }
}
```

Grafana needs well over `100Mi` to start. A limit of `32Mi` kills it every time.

## Step 4: Raise the memory limit

Set a request and a limit Grafana can start with. The command `kubectl set resources` edits the pod template, so a new Pod starts:

```sh
kubectl -n telemetry set resources deployment/grafana --requests=memory=128Mi --limits=memory=512Mi
kubectl -n telemetry rollout status deployment/grafana --timeout=180s
```

```text
deployment.apps/grafana resource requirements updated
deployment "grafana" successfully rolled out
```

Check the health endpoint through the API server proxy, and sign in through a port-forward:

```sh
kubectl get --raw /api/v1/namespaces/telemetry/services/grafana:3000/proxy/api/health
```

```json
{"commit":"...","database":"ok","version":"13.2.3"}
```

```sh
kubectl -n telemetry port-forward svc/grafana 3300:3000 >/dev/null 2>&1 &
curl -s -o /dev/null -w '%{http_code}\n' -u admin:starfleet http://127.0.0.1:3300/api/org
```

```text
200
```

Look for `"database":"ok"` and `200`. All three checks turn green. Stop the port-forward with `kill %1`.

## Submit

When all three checks are green in watch mode, stop it with `Ctrl+C` and submit once:

```sh
astrona submit --git ssh://git@github.com/astrona-io/ATS020.git -c sections/section-020/module-01/labs/lab-02
```

## Common mistakes

- **Creating the ConfigMap `grafana-storage`.** The volume then mounts, but Grafana fails with a read-only file system error, because a ConfigMap volume cannot be written. Use a volume Grafana can write to.
- **Renaming the environment variable or the Secret key reference.** Both are outside the allowed changes and the `only-allowed-changes` check fails. Change the Secret so it has the key the container already reads.
- **Changing the Secret and waiting for a login.** A running container keeps the environment it started with. The kubelet reads the Secret again only when it starts a new container, so a Pod that already runs needs `kubectl -n telemetry rollout restart deployment/grafana`.
- **Raising the request but not the limit.** The limit is what the kernel enforces. Raise the limit to at least `256Mi`.
- **Fixing the faults in another order.** That works. The Pod shows one fault at a time, so read the events after every change.

## If a check stays red

- `grafana-ready`: run `kubectl -n telemetry describe pod -l app=grafana` and read the last events. `OOMKilled` means the limit is still too low.
- `login-works`: read the key with `kubectl -n telemetry get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d`. It must print `starfleet`.
- `only-allowed-changes`: compare the container with the starting state. The image, the environment variable names, the probes and the data source mount must be as they were.
