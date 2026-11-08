# Summary

DORA metrics describe software delivery with four numbers. Deployment frequency and lead time for changes measure speed. Change failure rate and time to restore service measure stability. A platform team reads all four together, because speed without stability breaks production, and stability without speed stops delivery.

The data for the four numbers lives in three places. Git holds the commit times. The Argo CD Application holds the deployment history in `.status.history`, with a `revision` and a `deployedAt` for every deployment. The application controller exposes metrics that Prometheus scrapes: the counter `argocd_app_sync_total` and the gauge `argocd_app_info`.

Deployment frequency comes from the counter. The function `increase()` over a window, wrapped in `round(sum(...))` and filtered with `phase="Succeeded"`, gives the number of deployments. A recording rule in a PrometheusRule with the label `release: kps` stores the result as a series.

Change failure rate cannot come from failed syncs. A sync ends in `Succeeded` when Argo CD applied the manifests, even when the new pods can never start. The failure shows in the health status, which turns `Degraded` when the rollout does not finish before its deadline. A flag that is `1` while the Application is `Degraded` and `0` otherwise, counted with `changes()` and divided by two, gives the failed deployments. Divided by all deployments, it gives the rate. A rule that counts failed sync phases returns `0` and hides every failure.

Lead time and time to restore are durations between two timestamps. Lead time is the deployment time from the history minus the committer date from Git, joined on the commit hash. Time to restore is the deployment time of the first healthy deployment after a bad one minus the deployment time of the bad one. Flux gives the same signal as a Ready condition that goes false.

Each metric has a typical change that improves it. Smaller changes raise the frequency. Less waiting shortens the lead time. Checks before the merge lower the failure rate. A one-step revert and an alert on `Degraded` shorten the time to restore.

Key facts:

- `argocd_app_sync_total{name,phase}` counts sync operations, and `increase()` turns it into deployments in a window.
- `argocd_app_info{health_status}` is the signal for failed deployments, not the sync phase.
- `.status.history[]` of the Application holds `id`, `revision`, `deployStartedAt` and `deployedAt`.
- The Application history keeps only `revisionHistoryLimit` entries.
- A recording rule that Prometheus must select carries the label `release: kps` in this setup.

<!-- astrona:playground:destroy -->
