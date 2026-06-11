# 0001. Record architecture decisions

Date: 2026-06

## Status

Accepted

## Context

This repository is a reference internal developer platform: it exists to be read at least as much as it exists to be run. The decisions that shape it cut across several layers — a Copier-based golden path, an Argo CD app-of-apps tree, SHA-pinned GitHub Actions workflows, a Terraform blueprint that is validated but never deployed — and most of those decisions are not self-evident from the artifacts. A reviewer looking at [app-kube-prometheus-stack.yaml](../../deploy/argocd/apps/app-kube-prometheus-stack.yaml) can see that k3s control-plane scrape targets are disabled, but not why; someone forking the repo can see that the cloud tree has no apply step, but not whether that is an oversight or a posture.

Rationale that lives only in heads, chat threads, or pull request descriptions evaporates. PR discussions are tied to one hosting platform and disappear from forks and tarballs. The repository needs a durable, reviewable place for the "why", with the same lifecycle guarantees as the code itself.

## Decision

Architecture decisions are recorded as MADR-flavored ADRs in `docs/adr/`, numbered sequentially, one decision per file. Each ADR states its context, the decision, at least one real alternative that was seriously considered and the specific reason it lost, and the consequences — explicitly including the ones that hurt. An ADR that lists only upsides is not finished.

ADRs travel with the change they govern: the ADR is added or amended in the same pull request that introduces the decision, and it is reviewed with the same rigor as the code. Accepted ADRs are not rewritten when the decision changes; a new ADR supersedes the old one and the old one's status is updated to point at it. This keeps the record append-only and the history honest.

The bar for "needs an ADR" is: would a competent reviewer, six months from now, ask "why is it built this way?" If yes, write it down. Tooling choices with obvious defaults do not qualify; anything that constrains future structure does.

## Alternatives considered

A wiki or separate documentation site was the main alternative. It loses because it drifts: documentation that is not in the repository is not reviewed when the code changes, is not versioned with the code, and silently rots until it actively misleads. A wiki page describing the GitOps layout stays plausible long after the layout has moved on, and nothing in the merge process forces anyone to notice. It also does not survive a fork or an offline clone, which matters for a repository whose stated purpose is to be studied and reused.

Recording rationale in commit messages was also considered. Commit messages are durable and versioned, but they are scattered across history, not browsable as a coherent set, and effectively invisible to anyone who does not already know which commit to read.

## Consequences

The real cost is discipline. Every structurally significant change now carries a prose obligation, and that prose is reviewed like code — a reviewer is expected to reject an ADR with a strawman alternative or no painful consequence, which slows some pull requests down. The format only pays off if that bar is actually enforced; a half-maintained ADR directory is worse than none, because it claims an authority it no longer has.

In exchange, the rationale is greppable, versioned, fork-safe, and reviewable. Decisions 0002 and 0003 exist because this one does.
