"""fx-rates — scaffolded from the fastapi-service golden path."""

from __future__ import annotations

import logging
import os

from fastapi import FastAPI, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator

from app.logging_config import configure_logging
from app.rates import UnknownCurrencyError, all_quotes, supported_currencies

configure_logging()
logger = logging.getLogger("fx-rates")

app = FastAPI(
    title="fx-rates",
    description="Reference FX quotes service: serves indicative exchange rates with golden-signal metrics.",
    version=os.environ.get("SERVICE_VERSION", "dev"),
)

# /metrics with default HTTP golden-signal metrics (latency, traffic, errors).
# The platform scrapes it via pod annotations — no extra wiring needed.
Instrumentator().instrument(app).expose(app, include_in_schema=False)


@app.get("/healthz", include_in_schema=False)
def healthz() -> dict[str, str]:
    """Liveness: the process is up. No dependency checks here by design."""
    return {"status": "ok"}


@app.get("/readyz", include_in_schema=False)
def readyz() -> dict[str, str]:
    """Readiness: safe to receive traffic. Add dependency checks as they appear."""
    return {"status": "ready"}


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "fx-rates",
        "owner": "team-markets",
        "version": os.environ.get("SERVICE_VERSION", "dev"),
    }


@app.get("/rates")
def rates(base: str = "USD") -> dict[str, object]:
    """Indicative mid-market rates for one unit of ``base``."""
    try:
        quotes = all_quotes(base)
    except UnknownCurrencyError as exc:
        raise HTTPException(
            status_code=422,
            detail={"error": str(exc), "supported": supported_currencies()},
        ) from exc
    return {"base": base.upper(), "quotes": quotes, "kind": "indicative-mid"}
