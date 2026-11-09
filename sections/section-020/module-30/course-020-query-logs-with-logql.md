# Query Logs With LogQL

A LogQL selector chooses streams by labels, and a line filter selects records within those streams. Start with a namespace, filter actual error lines, then group counts by pod to identify the workloads that produced them.

<!-- astrona:playground:renew -->

## Select streams

A **stream selector** in curly braces picks streams by their labels. `=` means equal, `!=` not equal, `=~` matches a regular expression, and `!~` does not match one. A **regular expression** is a text pattern, and `.*` in it means any characters.

| Selector | Streams |
| --- | --- |
| `{namespace="outpost"}` | Everything in `outpost` |
| `{namespace="outpost", pod=~"probe-.*"}` | Only the `probe` Pods |
| `{namespace="outpost", pod!~"probe-.*"}` | Everything in `outpost` except `probe` |

Run the first selector against the API. The route `query_range` returns lines over a period, which `since` sets, and `limit` caps how many:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="outpost"}' \
  --data-urlencode 'since=10m' \
  --data-urlencode 'limit=20' |
  jq -r '.data.result[] | .stream.pod as $pod | .values[] | "\($pod) \(.[1])"'
```

Look for lines from several Pods. Each entry in `.data.result` is one stream, with its labels in `.stream` and its timestamped lines in `.values`.

In Grafana, open **Explore**, choose the `Loki` data source, switch the query editor to **Code**, type the same selector and run the query.

## Filter lines

A **line filter** comes after the selector and keeps or drops lines by their text. `|=` keeps lines that contain a string, `!=` drops them, `|~` keeps lines that match a regular expression, and `!~` drops them. The filters chain from left to right.

| Query | Result |
| --- | --- |
| `{namespace="outpost"} \|= "ERROR"` | Lines that contain `ERROR` |
| `{namespace="outpost"} \|= "ERROR" != "store"` | The same, without lines that contain `store` |
| `{namespace="outpost"} \|~ "(?i)error"` | `error` in any letter case |

The backslash in the table only protects the pipe character, so type `|=` in a query. Run the exact filter, then the one that ignores case:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="outpost"} |= "ERROR"' \
  --data-urlencode 'since=10m' \
  --data-urlencode 'limit=20' |
  jq -r '.data.result[] | .stream.pod as $pod | .values[] | "\($pod) \(.[1])"'
```

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="outpost"} |~ "(?i)error"' \
  --data-urlencode 'since=10m' \
  --data-urlencode 'limit=20' |
  jq -r '.data.result[] | .stream.pod as $pod | .values[] | "\($pod) \(.[1])"'
```

The first result has lines from `probe` and `depot`. The second also has `beacon`, whose line `level=INFO msg="retrying after error"` is not an error at all. A line filter is exact text, so choose the text that your applications write for a real failure.

## Turn lines into numbers

A **metric query** counts lines over a time window and returns numbers, not lines. Put the window in square brackets after the filter. `count_over_time` returns the number of lines per stream in the window, and `rate` returns the lines per second per stream. Then use an aggregation over the result, as in PromQL.

| Query | Answer |
| --- | --- |
| `rate({namespace="outpost"} \|= "ERROR" [5m])` | Error lines per second, for each stream |
| `count(rate({namespace="outpost"} \|= "ERROR" [5m]))` | How many streams wrote an error line |
| `sum(count_over_time({namespace="outpost"} \|= "ERROR" [5m]))` | How many error lines there are in total |
| `sum by (pod) (count_over_time({namespace="outpost"} \|= "ERROR" [5m]))` | How many error lines each Pod wrote |

A metric query can use the route `query`, which answers for one moment:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=count(rate({namespace="outpost"} |= "ERROR" [5m]))' |
  jq '.data.result'
```

Look for one entry whose `value` holds a timestamp and the number of streams. Now ask which Pods those are:

```sh
curl -fsSG http://127.0.0.1:3100/loki/api/v1/query \
  --data-urlencode 'query=sum by (pod) (count_over_time({namespace="outpost"} |= "ERROR" [5m]))' |
  jq -r '.data.result[] | "\(.metric.pod) \(.value[1])"'
```

Look for one row per Pod that wrote an error line, with its line count. That result is a list you can act on, and it did not need a single `kubectl logs`.

## Common pitfalls

> [!WARNING]
> **The wrong letter case.** `|= "ERROR"` does not match `error`, and `|~ "(?i)error"` also matches lines that only mention the word. Read a few matching lines before you act on a count.

> [!WARNING]
> **`count` read as a line count.** `count(rate(...))` counts streams, not lines. Use `sum(count_over_time(...))` for the number of lines.

> [!WARNING]
> **A log query on the `query` route.** Loki answers a query without a time window on the `query` route with HTTP status `400`. Use `query_range` for lines and `query` for metric queries.

> [!WARNING]
> **An empty result read as a broken query.** A metric query only sees its window. Once a Pod stops writing errors, a `[5m]` query returns no result after five minutes. Set a longer window to look further back.
