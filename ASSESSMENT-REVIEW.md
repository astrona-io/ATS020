# Lesson and quiz consistency review

This pass checks all registered question banks against the course navigation and reviews the answers against their cited lessons. It preserves published question IDs and the existing lab changes in this PR.

Corrections cover missing Prometheus series, the scope of a combined error ratio, explicit Grafana data-source editability, and the assumptions behind counting complete degraded episodes as failed deployments. Equivalent questions in the final domain bank receive the same corrections. The Prometheus and DORA lessons now explain those limits too.

CI checks that every quiz is registered, answer references are valid, question IDs are unique, declared counts match and each question links to an existing reading that precedes it. These checks detect structural regressions; they cannot prove the technical correctness of an answer. Existing lifecycle tests remain responsible for practical behavior.

Sources reviewed:

- [Prometheus query semantics and staleness](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana provisioning options](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Argo CD resource hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
