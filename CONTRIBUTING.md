# Contributing

This repository is a reference implementation, but it is run like a product:
pull requests flow through the same gates the platform advertises.

## Local setup

```bash
make doctor   # docker, k3d, kubectl, uv, git
make up       # the local platform
make test     # every test suite
make lint     # ruff + shellcheck
```

## Ground rules

- Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- CI must be green: change-scoped tests, Trivy, policy checks, catalog
  validation and the Terraform matrix all gate the merge.
- A new capability needs its verification path in
  [docs/capabilities.md](docs/capabilities.md) — a claim nobody can verify is
  a documentation bug.
- Decisions with alternatives get an ADR; the format is in
  [docs/adr/0001](docs/adr/0001-record-architecture-decisions.md).
- Add the `preview` label to a PR to get an ephemeral environment on any
  cluster running the platform.
