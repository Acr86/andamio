# 0008. Service catalog as validated YAML plus CLI now, Backstage when the triggers fire

Date: 2026-06

## Status

Accepted

## Context

A platform needs an authoritative answer to "what services exist, who owns them, how critical
are they, where is the runbook". The reflexive answer is Backstage. But Backstage is a Node
monorepo you operate: it needs a database, authentication, a build pipeline, and a steady diet
of upgrades across a fast-moving plugin ecosystem. For a platform currently serving one
demo service and one team, the portal would immediately become the largest and most
operationally demanding service on the platform — an inversion of priorities.

The actual requirements today are narrower: a machine-readable inventory, enforcement that the
inventory matches reality, and a human-readable view. None of those require a running server.

## Decision

The catalog is a directory of YAML files, one entry per service
([`catalog/`](../../catalog), schema in
[`catalog.py`](../../platform-cli/src/platform_cli/catalog.py) as Pydantic v2 models), managed
through the Typer-based `platform` CLI and enforced in CI by `platform validate`:

- Every entry is schema-validated (name, kind, owner, description, tier, lifecycle, links).
- Cross-checks bind the catalog to the repo tree: a `services/<name>/` directory without a
  catalog entry fails; an entry without deploy manifests fails with "would never deploy".
- Tier drives strictness, not just labels: t1/t2 entries require `links.runbook` pointing at a
  file that exists; t1 additionally requires `links.dashboard`.

`platform catalog render` produces a static HTML portal page (`dist/catalog/index.html`),
built as a CI artifact. Read-only, zero infrastructure, never down.

The schema is deliberately Backstage-mappable: name, owner, lifecycle, kind, and links
correspond mechanically to fields of a Backstage `catalog-info.yaml` entity, so migration is a
transform, not a re-inventory. The mapping is written down in
[docs/backstage-migration.md](../backstage-migration.md).

Migration triggers — adopt Backstage when any of these holds, not before:

1. More than three teams are onboarding services, so catalog browsing, search, and ownership
   discovery become daily multi-team activities rather than occasional lookups.
2. We need TechDocs, full-text search, or an RBAC'd UI — capabilities a static page
   structurally cannot provide.
3. A concrete plugin need appears (e.g. cost insights per service) that would otherwise be
   built bespoke.

## Alternatives considered

**Run real Backstage now.** It is the industry default and adopting it early avoids a
migration later. Rejected because the cost is not the install but the operation: a Node
monorepo with its own release cadence and notorious version churn across core and plugins,
plus a database and auth integration to run and patch. The platform team's biggest service
would be the portal itself, while the information it serves fits in a directory of YAML files
validated on every push. The Backstage-mappable schema keeps the migration cheap enough that
deferring carries little penalty.

**No catalog — derive everything from the repo tree.** Cheapest option, rejected because
ownership, tier, and runbook links do not live in the tree, and tier-conditional requirements
(t1 must have a dashboard) need a declared intent to validate against.

## Consequences

- There is no web UI for non-CLI users today. A product manager or auditor who wants to browse
  the catalog gets the static page or nothing; the CLI is the only interactive surface, and it
  assumes a cloned repo and a Python toolchain.
- The static catalog page is read-only and only as fresh as the last CI run; it cannot show
  live state (deployment health, current version) the way Backstage plugins can.
- The migration triggers demand honesty. If they fire and we delay, we will be hand-maintaining
  YAML at a scale it was explicitly not chosen for; the trigger list in this ADR is the
  commitment device.
- The schema must stay Backstage-mappable, which constrains future fields: anything we add
  should have a plausible home in a Backstage entity, or the cheap-migration claim erodes.
