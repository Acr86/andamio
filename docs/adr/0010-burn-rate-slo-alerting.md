# 0010. Alert on error-budget burn rate, not raw error rate

Date: 2026-06

## Status

Accepted

## Context

fx-rates has two explicit objectives ([docs/slo.md](../slo.md)): 99.5% availability over 30 days and p95 latency under 300ms. A 99.5% target leaves an error budget of 0.5% — roughly 3.6 hours of full outage per month. The alerting question is not "are there errors right now?" but "at the current rate, will we exhaust that budget?"

Those are different questions with different answers. A 30-second spike of 100% errors during a deploy consumes a negligible slice of the monthly budget; an alert that pages on it trains people to ignore pages. Conversely, a sustained 0.9% error rate sits below any plausible "errors > 1%" threshold while quietly burning the entire budget in about two weeks. Raw error-rate alerts fail in both directions at once: too loud for blips, silent for leaks.

## Decision

Alert on the rate at which the error budget is being spent, using the multi-window multi-burn-rate pattern, implemented in [observability/alerts/slo-burn-rate.yaml](../../observability/alerts/slo-burn-rate.yaml):

- FxRatesFastBurn — error ratio above 14.4x the budget rate over **both** a 5-minute and a 1-hour window, sustained for 2 minutes. Severity `page`. 14.4x means 2% of the 30-day budget is gone in one hour; if this is real, a human should be looking now.
- FxRatesSlowBurn — error ratio above 6x over **both** 30-minute and 6-hour windows, sustained for 15 minutes. Severity `ticket`. At 6x the budget is exhausted in about five days — urgent enough to fix this week, not urgent enough to wake anyone.

Requiring both windows to agree is the noise-reduction mechanism. The short window proves the problem is happening *now* (and makes the alert resolve quickly once fixed); the long window proves enough budget has actually been spent to matter. A deploy blip trips the short window but not the long one; a slow leak trips the long window and keeps the short one elevated.

Latency uses a simpler static rule (p95 > 300ms for 10 minutes, ticket) — a burn-rate construction over latency buckets was not worth the added opacity for one service.

Every alert carries a `runbook_url` annotation pointing into `docs/runbooks/` (the burn-rate alerts point at [rb-002](../runbooks/rb-002-fast-burn-slo.md)). An alert that fires without telling the responder what to do next is half an alert.

## Alternatives considered

Static threshold alerts ("error rate > 1% for 5m", "any 5xx in the last minute"). This is the default most teams start with, and it lost for the two symmetric failure modes above: it pages on transient spikes that cost effectively no budget, and it sleeps through any sustained error rate below the threshold — exactly the failure that destroys a monthly SLO. Static thresholds also encode no relationship to the SLO, so when the objective changes the thresholds silently stop meaning anything.

## Consequences

- Burn-rate math is genuinely unintuitive for newcomers — "14.4x over 5m AND 1h" does not explain itself. The explanation deliberately lives in two places the responder will actually look: [docs/slo.md](../slo.md) and the runbook. The alert expressions also inline the budget (0.005) rather than abstracting it, so the arithmetic is inspectable.
- With low traffic the ratios are noisy: at a handful of requests per minute, one or two 5xx responses can push a 5-minute window past 14.4x. Small-N noise is partly damped by the dual-window requirement and the `for:` clauses, but not eliminated. For a reference platform serving demo traffic this is accepted; a production deployment with real volume is exactly where this pattern gets cheaper, not more expensive.
- Only availability gets the full treatment. The latency objective is monitored by a static rule, which inherits the static-threshold weaknesses described above — an accepted asymmetry for one demo service.
