# Running Queries From The Command Line

The browser is fine for exploring, but most queries that matter run without one: in a script that checks a deployment, in a grader that decides whether a task is done, and in an exam terminal where a port-forward and `curl` are often the fastest way in. This part looks at the HTTP API behind every query, the JSON it returns, and how to pick out one value with `jq`.

## The query endpoint

Prometheus answers PromQL on `/api/v1/query`. It takes the query in a parameter called `query` and runs it as an instant query at the current time, or at the time in an optional `time` parameter. A query contains spaces, braces and quotes, so let `curl` encode it with `--data-urlencode`, which sends it as a form field in a `POST` request. Prometheus accepts both `GET` and `POST` on this endpoint.

Run the error ratio from the raw API and read the whole answer:

<!-- astrona:playground:renew -->

```sh
curl -s http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))' | jq .
```

You should see something like:

```text
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {},
        "value": [
          1791645974.090,
          "0.11792452830188681"
        ]
      }
    ]
  }
}
```

Every answer has the same frame:

- `status` is `success` or `error`. An error, such as a typo in the query, comes with `errorType` and `error` fields that say what is wrong.
- `data.resultType` says the shape of the result: `vector` for an instant vector, `matrix` for a range vector, `scalar` for a single number without labels, or `string`.
- `data.result` is a list with one entry per series. Each entry has `metric`, the series labels (empty here, because `sum` dropped them all), and `value`, a pair of a Unix timestamp and the value.
- `infos` and `warnings` appear only when Prometheus has a note about the query, such as a `rate()` on something that may not be a counter.

The value is a **string**, `"0.11792452830188681"`, not a number. Prometheus sends it that way so that special values like `NaN` and `+Inf` survive JSON. Compare it as a number only after converting it.

## Pick out one value

A script usually needs just the number. `jq -r` prints it without quotes:

```sh
curl -s http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum by (status) (rate(http_requests_total{namespace="starfleet"}[5m]))' |
  jq -r '.data.result[] | "\(.metric.status)\t\(.value[1])"'
```

You should see something like:

```text
200	1.3122807017543858
500	0.17543859649122806
```

This is the pattern the `promql` helper uses: walk `.data.result[]`, print the labels you care about and `.value[1]`. An empty answer is not an error. If no series match, `result` is an empty list, `status` is still `success`, and the `jq` filter prints nothing, so a script must treat "no output" as its own case.

To turn a value into a yes or no for a script, let `jq` do the comparison and set the exit code with `-e`:

```sh
curl -s http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(http_requests_total{namespace="starfleet", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="starfleet"}[5m]))' |
  jq -e '.data.result[0].value[1] | tonumber < 0.05'
echo "exit code: $?"
```

With about 12% errors, the comparison is false, and `jq -e` exits with `1`:

```text
false
exit code: 1
```

`jq -e` exits with `0` when the last output is true and `1` when it is `false` or `null`. An empty result fails too, with a different message: `tonumber` cannot convert the missing value, so `jq` prints `null (null) cannot be parsed as a number` and exits with `5`. Either way the check only passes when the query returned a value and the value meets the condition, which makes it a safe building block for a script.

You can now run any PromQL query from a terminal, read the frame of the answer, and turn a result into a value or an exit code. Together with selectors, rates, aggregation, ratios and percentiles, that covers the queries an alert, a dashboard or a grader needs.

## Common pitfalls

> [!WARNING]
> - **Building the query into the URL by hand.** Braces, quotes and `+` break it; use `--data-urlencode`.
> - **Comparing the value as a number without converting it.** The API returns it as a string; use `tonumber` in `jq`.
> - **Treating an empty `result` as success.** `status` is `success` even when no series matched; check that a value exists.
> - **Querying while the port-forward is down.** `curl` then prints nothing and `jq` reports a parse error, which looks like a query problem.
