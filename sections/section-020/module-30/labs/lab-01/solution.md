# Solution: Repair A Loki Error Dashboard

## Inspect the starting state

```sh
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

Use Grafana Explore to run `{namespace="outpost"} |= "ERROR"`. Inspect the Pod labels of returned log streams.

## Make the repair

Open Grafana at `http://127.0.0.1:3000` with `admin` / `starfleet`. In the Loki data source, set Maximum lines to `250`. Save the dashboard with these queries:

```logql
{namespace="outpost"} |= "ERROR"
```

```logql
count(rate({namespace="outpost"} |= "ERROR" [5m]))
```

## Verify the result

Reload the saved dashboard and run each query with a recent time range.

When the result matches the task, submit the lab:

```sh
astrona submit -c sections/section-020/module-30/labs/lab-01
```
