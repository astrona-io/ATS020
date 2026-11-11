# Question

Solve this question on: `terminal`

The `outpost-policy` admission webhook blocks Deployment creation in `outpost`. Its server and Service run in `webhook-system`.

## Tasks

1. Attempt a Deployment create and read the certificate error.
2. Inspect the serving certificate and its expiry date.
3. Sign and install a new serving certificate using the existing CA. Restart the webhook server.
4. Create a Deployment successfully, confirm a new admission request in the server log, and delete your test Deployment.

## Constraints

- Keep the webhook configuration, its namespace selector, Deployment rules, Service and `failurePolicy: Fail`.
- Keep the trusted CA unchanged.
- Do not bypass admission.
