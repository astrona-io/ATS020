# Diagnosing And Remediating Incidents

Makes the reader able to find and fix the cause of a broken workload or a broken platform component, using events, logs, status conditions and metrics, and to prove the fix. It comes last because it uses every tool the earlier sections taught, under the time pressure of an incident.

**Curriculum item covered:** Diagnosing and Remediating Platform Issue and Incident Scenarios

---

## What You Will Master

- Follow a fixed triage order — status, events, describe, logs, previous logs — to find a pod's failure cause
- Fix a Pending pod caused by too-large requests, a missing PersistentVolumeClaim or an unmatched node selector
- Fix a CrashLoopBackOff caused by a bad command, a missing ConfigMap key or a failing liveness probe
- Fix an OOMKilled container by reading its usage and setting a fitting memory limit
- Fix an ImagePullBackOff caused by a wrong tag or a missing pull secret
- Find a failing admission webhook from the API server error message and fix its Service without deleting it
- Find an expired webhook serving certificate from the `x509` error text and `openssl`, and replace it
- Find a stopped or crashing controller from its Deployment, logs and the resources that stop reconciling
- Read the sync status and health status of an Argo CD Application, and find why it is OutOfSync or Degraded with `argocd app diff` and `kubectl describe application` (bad path, bad targetRevision, failing hook, degraded child resource)
- Prove each fix by the behaviour it restores (create succeeds, resource reconciles, pods are Ready, sync is Healthy)
