# ADR-0013 — Isolate package and texture I/O behind asynchronous boundaries

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-012
- ISSUE: ISSUE-003

## Context

The AppKit import and startup flows synchronously inspected packages, decoded
every referenced image and copied installed content on the main actor.
`PetStore` also waited for `unzip` and `ditto` to terminate before draining
their pipes, so enough output could block a child and its parent indefinitely.
The display callback's view synchronously decoded a Metal texture for every new
frame URL and had no repeat-hit or memory policy.

## Decision

Make installation and application package inspection explicitly asynchronous.
Run all filesystem enumeration, archive processes, conversion, checks and image
validation off the main actor; publish only a completely validated result.
Execute external processes through one runner that drains output while the
child is running, bounds retained diagnostics, supports cancellation and
enforces a timeout.

Load renderer textures through an actor-owned, decoded-byte-bounded LRU. A
generic core cache owns hit, coalescing, eviction and invalidation semantics;
the Metal adapter owns decoding and an unchecked-sendable resource wrapper.
Keys contain the pet session generation. Views cancel obsolete frame waiters
and reject late completions; a package switch invalidates the entire old
namespace.

## Consequences

Package import and image decode no longer monopolize the main actor or display
callback. Full child pipes cannot deadlock the parent, repeated frames reuse
textures, concurrent duplicate requests coalesce, and retained decoded memory
has an explicit ceiling. Failed or cancelled asynchronous work never publishes
a partial package or a stale texture.

The synchronous importer primitive remains public for validators and tests;
application code is prohibited from calling it directly. Metal resources need
an explicitly reviewed `@unchecked Sendable` wrapper because the framework
protocol predates Swift concurrency.
