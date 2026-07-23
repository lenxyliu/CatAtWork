# ADR-0006 — Declare hosted validation dependencies

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-004
- ISSUE: ISSUE-009

## Context

The high-frame validator imports Pillow. Local validation passed only because
Pillow 11.3.0 was already installed, while the clean GitHub runner failed with
`ModuleNotFoundError`. Hosted evidence cannot depend on mutable image
contents.

## Decision

Provision Python 3.13 with `actions/setup-python@v6`, install exact versions
from `Scripts/requirements-validation.txt`, and pin Pillow 12.3.0. Print the
Python and Pillow identities before running validation.

## Consequences

Hosted image checks are reproducible and no longer depend on accidental
runner packages. CI gains a network dependency on Python setup and PyPI; a
future version change requires a new CHG/TR and must remain compatible with
the validation scripts.
