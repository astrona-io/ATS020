# Section 040: Measuring Platform Efficiency

Makes the reader able to measure how well the platform delivers and how well it uses resources: the four DORA metrics from GitOps history, service level objectives with error budgets, and the gap between requested and used CPU and memory. It comes after the collection sections because every number here is a Prometheus query on data those sections taught to collect.

**Curriculum item covered:** Measuring and Improving Platform Efficiency Using Deployment Metrics and Performance Indicators

---

## What You Will Master

- Define deployment frequency, lead time for changes, change failure rate and time to restore service
- Count deployments over a time window from the GitOps controller's sync metrics in Prometheus
- Calculate lead time from a commit time in Git and the sync time recorded by the controller
- Calculate change failure rate and time to restore from failed and recovered deployments
- Name one change to the delivery process that improves each metric
- Write an SLI as a PromQL ratio of good requests to all requests
- Calculate the remaining error budget for a 99% SLO over a window
- Write a burn-rate alert that fires when the budget would run out early
- Compare container CPU and memory requests with real usage from metrics-server and Prometheus
- Name the workload with the biggest gap and change its requests to match usage
