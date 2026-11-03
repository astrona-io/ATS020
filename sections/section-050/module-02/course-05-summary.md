# Summary

A platform component fails differently from a workload. The failing component sits next to the thing you were doing, and the symptom shows up in your command or in a missing result. The method is the same each time: read the error text, name the component that should have done the work, read the object that component owns, fix the cause, and prove the fix with the behaviour that was lost.

An admission webhook is an HTTPS service that the API server calls before it stores an object. A `ValidatingWebhookConfiguration` names the requests to send, the Service to call and the `failurePolicy`. With `Fail`, the API server rejects the request when the call fails, so one broken webhook can block every create it matches. The error text names the webhook, the Service and the reason. A `connection refused` error means the Service has no endpoint behind it. The EndpointSlice and the Service selector against the pod labels show the cause, and the fix is the selector or the port of the Service.

An `x509: certificate has expired` error means the connection worked and the API server rejected the certificate. `openssl x509` shows the subject, the issuer and the dates of a certificate, and the `caBundle` of the webhook configuration shows which CA the API server trusts. A new serving certificate must come from the same CA, must list the Service name as a subject alternative name, and must reach the server. A webhook server that reads its certificate at start needs a restart after the Secret changes.

A controller reconciles objects. If it stops, the API server still stores new objects, and the status of old objects stays as the controller last wrote it. The sign of a stopped controller is an object that exists and has no effect, together with a Deployment at `0/0`. The Prometheus Operator turns a ServiceMonitor and a PrometheusRule into Prometheus configuration, so with the operator stopped, `up{job="scout"}` has no series and the rule is not loaded. Scaling the Deployment to one replica fixes it, and the proof is `up == 1` and the rule in the Prometheus API.

A GitOps Application has two status fields. The sync status says whether the cluster matches Git, and the health status says whether the resources work. A bad `path` or `targetRevision` gives a `ComparisonError` condition and sync status `Unknown`. A failing hook stops the sync and leaves the Application `OutOfSync`, and the reason is in the logs of the hook pod. A `Synced` and `Degraded` Application has a child resource that does not start, and you find it in the resource table and in its own events and logs. `argocd app diff` shows what differs between Git and the cluster. The fix always goes into Git, because Argo CD, or a later sync, undoes a change made on the live object.

The shortcuts do not count as fixes. Setting `failurePolicy: Ignore` or deleting a webhook configuration removes the policy together with the error. A fix keeps the safety and removes the cause.

The key facts to remember are these:

- The API server, not `kubectl`, calls an admission webhook, so the error comes from the API server.
- `failurePolicy: Fail` rejects a request when the webhook cannot be reached.
- `connection refused` on a webhook Service points to an empty EndpointSlice.
- An `x509` error with a date gives the expiry, and `openssl x509 -noout -enddate` confirms it.
- A status written by a controller is only as fresh as the controller.
- An Application can be `Synced` and `Degraded` at once.
- A fix is proved by the behaviour it restores, not by an object that exists.

<!-- astrona:playground:destroy -->
