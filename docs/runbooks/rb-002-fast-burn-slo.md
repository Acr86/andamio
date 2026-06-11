# RB-002: fx-rates fast error-budget burn

**Alert:** `FxRatesFastBurn` — error ratio above 14.4x budget burn on both the 5m and 1h windows. `FxRatesSlowBurn` and `FxRatesP95LatencyHigh` also route here at ticket urgency.

**Severity:** page

## Symptoms

- The page fired, which already encodes the math: the SLO is 99.5% availability over 30 days, an error budget of about 3.6 hours per month. At 14.4x burn, the hour-window's budget share (2% of the month) is gone in roughly 4 minutes of hard outage. Both alert windows agreeing means this is sustained, not a blip.
- Clients of `GET /rates` see 5xx responses.

## Triage

Mitigate first, diagnose second. The budget math above is the reason: do not read logs while burning at 14.4x.

1. Open the Service Golden Signals dashboard in Grafana (`make grafana-password` for credentials). The error-ratio panel tells you the blast radius; the p95 panel tells you whether this is errors, latency, or both.
2. Correlate with the last promotion:

       gh run list --workflow release.yml --limit 5
       git log -1 origin/main
       kubectl -n services rollout history deployment/fx-rates

   If the burn started within minutes of a `release.yml` promotion, treat it as deploy-correlated until proven otherwise.
3. If deploy-correlated, execute RB-003 now and come back. Rollback is a pointer move; it is cheaper than any diagnosis.
4. If the rollout history is quiet (no recent promotion), the errors are dependency- or environment-shaped. Check pod health and recent restarts:

       kubectl -n services get pods -l app.kubernetes.io/name=fx-rates
       kubectl -n services describe deployment/fx-rates

5. Read the application logs — single-line JSON, so status codes and paths are greppable:

       kubectl -n services logs deploy/fx-rates --since=15m

   Cross-check the status-code breakdown against the dashboard traffic panel: uniform 500s across all paths point at startup/config; 500s on `/rates` only point at the quote-crossing logic.

## Resolution

- Deploy-correlated: roll back per RB-003, confirm the error ratio on the dashboard returns to baseline, then diagnose the bad change offline against the rolled-back budget you have left.
- Not deploy-correlated: fix the failing layer (pod scheduling, resource limits, ingress) and watch the 5m window recover; the alert clears when both windows drop below threshold.
- Either way, once the burn stops, file the follow-up with the evidence lines from the logs and the dashboard time range.

## Root causes seen

- A bad promotion: code change passed tests but failed against real traffic shapes. Caught fast because every fast burn so far started within one scrape interval of a rollout.
- Resource limits too tight after a dependency bump — pods OOM-killed in a loop, presenting as intermittent 5xx through the ingress rather than a clean outage.

## Automation status

Detection is fully automated: the multi-window, multi-burn-rate rules page only on sustained budget spend, so a firing alert is actionable by construction. Classification is assisted — when the failure also reddens CI, the `ci-triage` workflow attaches a taxonomy and owner hint to the run. Mitigation is three commands away (RB-003). The residual human decision is the fork in step 3: deploy-correlated or not. Promotion-gated deploys keep most fast burns deploy-shaped, which keeps that decision fast.
