# Summary

Loki stores log lines and indexes only their labels, and lines with the same set of labels form a stream. Grafana reads Loki through a data source. The web interface generates the data source's unique identifier, and the API lets you choose it, which matters because panels refer to a data source by that value. The address must work from inside the Grafana Pod, so it uses the Service name and never `localhost`. **Maximum lines** is stored as `jsonData.maxLines`, a string after a save in the web interface and a number if an API client sends one. A `PUT` replaces the whole data source, so read it, change the field and send it all back. Grafana refuses changes to a provisioned data source.

A LogQL query starts with a stream selector such as `{namespace="outpost"}`. A line filter such as `|= "ERROR"` then keeps lines by exact, case-sensitive text. A metric query adds a window in square brackets: `count_over_time` returns lines per stream and `rate` returns lines per second per stream. `count(rate({namespace="outpost"} |= "ERROR" [5m]))` counts the streams with errors, and `sum by (pod) (count_over_time(...))` counts lines per Pod. Loki answers a log query only on `query_range`, while a metric query also works on `query`.

An edit in a Grafana panel saves into Grafana's database. It is fast and suits an incident, but it has no review and is lost with the database. Dashboards as code keep the JSON in version control and restore it when Grafana starts empty. Grafana also refuses saves over a provisioned dashboard. To act on a query result, follow each Pod's owner to its controller and scale that controller, because a deleted Pod comes back at once.

Key facts:

- `POST /api/datasources/` creates a data source, and `GET` and `PUT` on `/api/datasources/uid/<uid>` read and replace it.
- `GET /api/datasources/uid/<uid>/health` tests the connection from inside Grafana.
- `GET /api/dashboards/uid/<uid>` reads a dashboard, and `POST /api/dashboards/db` saves it.
- A window must be long enough to reach the lines: a `[5m]` query returns nothing five minutes after a Pod stops writing them.

<!-- astrona:playground:destroy -->
