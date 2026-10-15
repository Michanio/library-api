# 1. Record architecture decisions

Date: 2026-10-15
Status: Accepted

## Context

This project involves several design decisions with real trade-offs, such as how borrowing state is modelled, how reminder emails are scheduled and how the API exposes status changes. Reviewers and future contributors, both human and AI assistants, need to understand why each choice was made and what was rejected, not only what the code does.

## Decision

We record significant design decisions as Architecture Decision Records in `docs/adr/`.

- Each ADR is a numbered Markdown file (`NNNN-title.md`), created with `bin/rails g adr "Title" [--status=Accepted]`.
- The format follows Michael Nygard's template (Context, Decision, Consequences) with an extra "Alternatives considered" section.
- An ADR is written only when a decision has meaningful trade-offs. Choices dictated by the task (for example, PostgreSQL) or by Rails defaults are not recorded.
- Accepted ADRs are not rewritten. A changed decision gets a new ADR, and the old one's status becomes "Superseded by NNNN".

## Alternatives considered

- **Explaining decisions only in the README:** this mixes setup instructions with rationale, and the README becomes hard to scan as decisions accumulate. The README links to the ADRs and summarizes them instead.
- **Relying on commit messages:** they capture the rationale at the time, but they're hard to find later and are scattered across history.
- **adr-tools:** a widely used shell tool, but an extra non-Ruby dependency. A small Rails generator (`lib/generators/adr/`) fits the existing `bin/rails g` workflow.

## Consequences

- (+) The reasoning behind decisions is easy to find and can be reviewed together with the code that implements them.
- (+) `CLAUDE.md` points AI assistants to `docs/adr/`, so they keep to past decisions across sessions.
- (+) The README can stay focused on setup and usage.
- (−) Each significant decision has a small writing overhead.
- (−) Deciding what counts as "significant" is a judgement call.
