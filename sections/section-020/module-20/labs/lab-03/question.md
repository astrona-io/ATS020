# Question

Solve this question on: `terminal`

The `logs` Collector has working permissions and a scrape target, but its file receiver watches the wrong directory.

## Tasks

1. Inspect the Collector hostPath mount and receiver include pattern.
2. Find the container log path on the node.
3. Repair the file receiver include pattern while excluding the Collector's own logs.
4. Verify that fresh `probe` errors produce a rising labelled counter in Prometheus.

## Constraints

- Keep the DaemonSet, read-only host log mount, container parser, metadata processor and count connector.
- Keep the Collector logs excluded to avoid collecting its own output.
