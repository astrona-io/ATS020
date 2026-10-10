# Selecting Time Series

Every PromQL query starts by choosing which data to look at. Prometheus stores thousands of series, and a query that picks the wrong ones returns a believable number that answers the wrong question. This part shows what a single series is, how label matchers narrow the choice, and the two shapes of result a selector can return.

## One metric, many series

A **time series** is one metric name plus one exact set of label values, with a value stored at every scrape. A **label** is a key-value pair, such as `namespace="starfleet"`, that tells series apart. The metric `http_requests_total` from `scout` is not one series: each pod and each HTTP status code gets its own.

Prometheus adds some labels itself when it scrapes. `namespace`, `pod`, `service`, `job` and `instance` describe where the series came from. The application adds others; `scout` adds `status`, the HTTP status code of the answer.

## Run your first query

Start a port-forward to Prometheus in a second terminal and leave it running:

<!-- astrona:playground:renew -->

```sh
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

You can type queries on the page `http://127.0.0.1:9090/query` in a browser. In the terminal, use a small helper that sends a query to Prometheus's HTTP API and prints each series as its labels and its value. Paste it into your first terminal:

```sh
promql() {
  curl -s http://127.0.0.1:9090/api/v1/query --data-urlencode "query=$1" |
    jq -r '.data.result[] | "\(.metric | del(.__name__) | to_entries | map("\(.key)=\(.value)") | join(","))\t\(.value[1])"'
}
```

Now select the request counter of the `starfleet` `scout`:

```sh
promql 'http_requests_total{namespace="starfleet"}'
```

You should see something like:

```text
container=scout,endpoint=http,instance=10.244.0.9:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-4fbxc,service=scout,status=200	422
container=scout,endpoint=http,instance=10.244.0.9:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-4fbxc,service=scout,status=500	61
container=scout,endpoint=http,instance=10.244.0.10:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-qb8fj,service=scout,status=200	405
container=scout,endpoint=http,instance=10.244.0.10:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-qb8fj,service=scout,status=500	54
```

The query returned four series: two pods, each with a `200` and a `500` series. Each value is the total number of requests that pod has answered with that status since it started. Your numbers grow every second, and your pod names and addresses differ.

## Label matchers

The part in curly braces is a list of **label matchers**. Each one compares a label with a value, and a series is selected only when all matchers are true. There are four operators:

| Matcher | Selects series where the label |
| --- | --- |
| `status="500"` | equals the value |
| `status!="200"` | does not equal the value |
| `status=~"5.."` | matches the regular expression |
| `status!~"2.."` | does not match the regular expression |

A regular expression matcher must match the **whole** label value. `status=~"5.."` matches `500` and `503`, but `status=~"5"` matches nothing, because no status is exactly `5`. Select every server error from the `starfleet` `scout`:

```sh
promql 'http_requests_total{namespace="starfleet", status=~"5.."}'
```

You should see something like:

```text
container=scout,endpoint=http,instance=10.244.0.9:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-4fbxc,service=scout,status=500	61
container=scout,endpoint=http,instance=10.244.0.10:9898,job=scout,namespace=starfleet,pod=scout-674cfb4855-qb8fj,service=scout,status=500	54
```

Only the `500` series remain. Use regular expressions for families of values, such as all `5xx` codes or several namespaces (`namespace=~"starfleet|outpost"`), and exact matches everywhere else, because they are faster and harder to get wrong.

## Instant vectors and range vectors

The queries so far returned an **instant vector**: one value per series, the latest one at the time of the query. Add a time range in square brackets and the same selector returns a **range vector**: every stored value of each series inside that window.

Range vectors cannot be drawn or compared directly; functions such as `rate()` take them as input. The helper above only prints instant vectors, so look at one range vector through the raw API, for a single series over the last minute:

```sh
curl -s http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=http_requests_total{namespace="starfleet",status="500",pod="<POD>"}[1m]' |
  jq '.data.resultType, .data.result[0].values'
```

Replace `<POD>` with one of your `scout` pod names from the output above. You should see something like:

```text
"matrix"
[
  [
    1791645916.064,
    "56"
  ],
  [
    1791645931.064,
    "58"
  ],
  [
    1791645946.064,
    "60"
  ],
  [
    1791645961.064,
    "61"
  ]
]
```

The result type is `matrix`, the API's name for a range vector, and the series has four samples in one minute, one every 15 seconds, each a pair of a Unix timestamp and a value. The counter went from `56` to `61` in that minute, which is the kind of change the next step turns into a rate.

You can now select exactly the series you mean, with exact and regular expression matchers, and you know that a selector with `[...]` returns a window of samples instead of one value. The raw totals themselves are hard to use, though: they only ever grow, and they reset when a pod restarts. The open question is how to turn them into a number that means something now.

## Common pitfalls

> [!WARNING]
> - **Writing a partial regular expression.** `=~` must match the whole value; use `"5.."`, not `"5"`.
> - **Forgetting that one metric is many series.** A selector without filters returns every pod and every status; check the labels before you trust a number.
> - **Reading a counter's value as a current level.** `422` is the total since the pod started, not requests per second.
> - **Putting a range vector where a value is expected.** A query that ends in `[1m]` cannot be drawn or compared; wrap it in a function such as `rate()`.
