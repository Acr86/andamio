# 0007. Copier golden paths: one render produces service, manifests, and catalog entry

Date: 2026-06

## Status

Accepted

## Context

Most scaffolding setups fail in two predictable ways. First, the template generates the
service code but "registering" it — adding deployment manifests, a catalog entry, CI wiring —
is a separate manual step, and separate steps get forgotten. The result is services that exist
in the repo but never deploy, or deploy but are invisible to the platform. Second, templates
are scaffold-once: a year later the template has better probes, tighter security contexts, and
a fixed Dockerfile, while every service scaffolded before that improvement is frozen at the
state of the template on the day it was rendered. Template evolution is the golden-path
maintenance problem most platforms ignore, and it is where golden paths quietly rot.

A third, smaller failure mode: templates rendered from whatever happens to be in the author's
working tree, so two people scaffolding "the same" service on the same day get different output.

## Decision

Golden paths are [Copier](../../templates/fastapi-service/copier.yml) templates that render
relative to the repository root. A single `platform new service NAME --owner X --tier tN`
render produces, in one pass:

- `services/<name>/` — FastAPI source, tests, non-root Dockerfile, pyproject
- `deploy/kustomize/services/<name>/` — hardened base plus `local` and `preview` overlays
- `catalog/<name>.yaml` — the catalog entry

There is no registration step because there is nothing left to register: the services
ApplicationSet picks up the new overlay directory on merge, and `platform validate` fails CI
if any of the three artifacts is missing relative to the others.

Copier writes `.copier-answers.yml` into the rendered service. That file is provenance — which
template, which version, which answers — and it is what makes `copier update` work: when the
template gains an improvement, each service can replay its recorded answers against the new
template version and receive the diff as a three-way merge. Template fixes propagate to
existing services instead of only blessing future ones.

Scaffolds render from committed template state only
([`vcs_ref="HEAD"` in scaffold.py](../../platform-cli/src/platform_cli/scaffold.py)). A dirty
working tree never leaks into a generated service; two renders of the same commit are identical.

## Alternatives considered

**cookiecutter.** The de facto default and simpler to author. Rejected because it has no
update story — a cookiecutter render is a one-shot copy with no record of the inputs, so
propagating template evolution means hand-porting diffs into every service. It also keeps no
answers provenance, so "which template version is this service on?" is unanswerable without
archaeology. Since template maintenance is the explicit problem we are solving, losing both is
disqualifying.

**Backstage software templates.** Solves scaffolding plus gives a UI, but only as part of
adopting Backstage wholesale, which is a separate decision with its own cost structure — see
[ADR-0008](0008-catalog-cli-now-backstage-later.md). Notably, Backstage scaffolder templates
are also scaffold-once; it would not have solved the update problem either.

## Consequences

- Because Copier renders from `HEAD`, template authors must commit before they can try their
  own template. The edit–render–inspect loop requires a commit (or amend) per iteration, which
  is genuinely slower than rendering from the working tree. We accept this for reproducibility.
- `copier update` is a merge, not magic. A service that has locally edited a templated file —
  which is normal and expected — will hit conflicts when the template changes the same region,
  and someone has to resolve them per service. The answers file makes updates possible, not free.
- Each service carries a `.copier-answers.yml` that must not be hand-edited; corrupting it
  silently breaks the update path for that service.
- One golden path exists today (FastAPI). A second stack means a second template to author and
  maintain to the same standard, and the maintenance cost scales with template count.
