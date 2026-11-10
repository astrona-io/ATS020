# Prerequisites

You need these tools on your machine: `astrona`, `kubectl`, `curl` and `jq`. The lab checks the last three before it starts.

You need to know how to read and change the environment variables of a Deployment with `kubectl set env`, wait for a rollout with `kubectl rollout status`, and read pod logs with `kubectl logs`. You need to know the address form of a Service in another namespace: `<service>.<namespace>`. A span records one timed step of a request. A span event is a timestamped record inside a span; the event `exception` records an error with its type, message and stack trace.

The lab starts a single-node `kind` cluster with Kubernetes 1.35, Jaeger 2.23.0 and one small Python program that sends spans over OTLP/HTTP. Allow a minute or two for the first start.

The lab opens one port on your machine, on `127.0.0.1` only: `26686` for the Jaeger web interface. It is not the usual port (`16686`), so a Jaeger already running on your machine does not block it. Keep `26686` free before you start.
