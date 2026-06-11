# fx-rates

Reference FX quotes service: serves indicative exchange rates with golden-signal metrics.

Owned by **team-markets** · tier **t3** · scaffolded from the `fastapi-service` golden path.

## Develop

```bash
cd services/fx-rates
uv run --extra dev pytest        # run the test suite
uv run uvicorn app.main:app --reload --port 8000
```

## Endpoints the platform relies on

| Path | Purpose |
|---|---|
| `/healthz` | liveness probe |
| `/readyz` | readiness probe |
| `/metrics` | Prometheus scrape target (golden-signal HTTP metrics) |

## Deploy

Nothing to configure: `deploy/kustomize/services/fx-rates/` was rendered
alongside this service and GitOps picks it up on merge. The image is built, scanned
and published by CI; the deployed tag is promoted by digest, never rebuilt.

To update this service when the golden-path template evolves:

```bash
cd services/fx-rates && copier update
```
