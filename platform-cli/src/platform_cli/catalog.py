"""Service catalog: schema, loading, and structural validation.

The catalog is a directory of YAML files, one entry per file, deliberately
shaped so each entry maps mechanically onto a Backstage ``catalog-info.yaml``
entity (see docs/backstage-migration.md). The catalog is the source of truth:
``platform validate`` cross-checks it against what actually exists in the
repository, and CI runs the same check, so the catalog can never drift from
reality and still pass a build.
"""

from __future__ import annotations

import re
from enum import StrEnum
from pathlib import Path

import yaml
from pydantic import BaseModel, ConfigDict, Field, field_validator

from . import repo

NAME_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,40}[a-z0-9]$")


class Kind(StrEnum):
    SERVICE = "service"
    TOOL = "tool"
    SYSTEM = "system"


class Tier(StrEnum):
    """Operational criticality. Drives validation strictness, not just labels."""

    T1 = "t1"  # critical path: paging, runbook and dashboard required
    T2 = "t2"  # important: runbook required
    T3 = "t3"  # experimental / internal


class Lifecycle(StrEnum):
    EXPERIMENTAL = "experimental"
    PRODUCTION = "production"
    DEPRECATED = "deprecated"


class Links(BaseModel):
    model_config = ConfigDict(extra="forbid")

    runbook: str | None = None
    dashboard: str | None = None
    source: str | None = None


class Entry(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    kind: Kind
    owner: str
    description: str = Field(min_length=10)
    tier: Tier = Tier.T3
    lifecycle: Lifecycle = Lifecycle.EXPERIMENTAL
    language: str | None = None
    template: str | None = None
    links: Links = Field(default_factory=Links)

    @field_validator("name")
    @classmethod
    def name_is_kebab_case(cls, value: str) -> str:
        if not NAME_PATTERN.match(value):
            raise ValueError(
                f"{value!r} must be kebab-case (lowercase letters, digits, hyphens), "
                "3-42 characters, and must not end with a hyphen"
            )
        return value


class CatalogError(Exception):
    """One or more catalog entries are invalid or inconsistent with the repo."""

    def __init__(self, problems: list[str]) -> None:
        self.problems = problems
        super().__init__("\n".join(problems))


def load_entries(root: Path) -> list[Entry]:
    """Load and schema-validate every entry. Raises CatalogError listing all problems."""
    entries: list[Entry] = []
    problems: list[str] = []
    for path in sorted(repo.catalog_dir(root).glob("*.yaml")):
        try:
            raw = yaml.safe_load(path.read_text(encoding="utf-8"))
            entry = Entry.model_validate(raw)
        except Exception as exc:  # noqa: BLE001 - we aggregate every failure for the report
            problems.append(f"{path.name}: {exc}")
            continue
        if entry.name != path.stem:
            problems.append(
                f"{path.name}: entry name {entry.name!r} must match the file name {path.stem!r}"
            )
        entries.append(entry)
    if problems:
        raise CatalogError(problems)
    return entries


def cross_check(root: Path, entries: list[Entry]) -> list[str]:
    """Consistency checks between the catalog and the repository tree.

    Returns a list of problems (empty when consistent). This mirrors the
    snapshot-drift pattern: the committed inventory must always match what
    the code says, and the check is cheap enough to run on every push.
    """
    problems: list[str] = []
    by_name = {entry.name: entry for entry in entries}

    services_on_disk = {
        path.name for path in repo.services_dir(root).iterdir() if path.is_dir()
    } if repo.services_dir(root).is_dir() else set()
    manifests_on_disk = {
        path.name for path in repo.kustomize_services_dir(root).iterdir() if path.is_dir()
    } if repo.kustomize_services_dir(root).is_dir() else set()

    service_entries = {e.name for e in entries if e.kind is Kind.SERVICE}

    for orphan in sorted(services_on_disk - service_entries):
        problems.append(
            f"services/{orphan} exists but has no catalog entry "
            f"(catalog/{orphan}.yaml is missing or not kind=service)"
        )
    for ghost in sorted(service_entries - services_on_disk):
        problems.append(f"catalog/{ghost}.yaml declares a service but services/{ghost}/ is missing")
    for unmanaged in sorted(service_entries - manifests_on_disk):
        problems.append(
            f"catalog/{unmanaged}.yaml declares a service but "
            f"deploy/kustomize/services/{unmanaged}/ is missing — it would never deploy"
        )

    for entry in entries:
        if entry.kind is not Kind.SERVICE:
            continue
        if entry.tier in (Tier.T1, Tier.T2) and not entry.links.runbook:
            problems.append(
                f"{entry.name}: tier {entry.tier} services must link a runbook (links.runbook)"
            )
        if entry.tier is Tier.T1 and not entry.links.dashboard:
            problems.append(
                f"{entry.name}: tier t1 services must link a dashboard (links.dashboard)"
            )
        if entry.links.runbook and not (root / entry.links.runbook).is_file():
            problems.append(
                f"{entry.name}: links.runbook points to {entry.links.runbook!r} "
                "which does not exist in the repository"
            )

    duplicate_owners_missing = [e.name for e in entries if not e.owner.strip()]
    for name in duplicate_owners_missing:
        problems.append(f"{name}: owner must not be blank")

    return problems


def validate(root: Path) -> list[Entry]:
    """Full validation: schema plus cross-checks. Raises CatalogError on any problem."""
    entries = load_entries(root)
    problems = cross_check(root, entries)
    if problems:
        raise CatalogError(problems)
    return entries
