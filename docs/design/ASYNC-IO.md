# Asynchronous package and texture I/O

## Rules

- Directory inspection, ZIP extraction, path/security checks that touch disk, image decoding/validation, checksumming, and import copies run outside the main actor.
- UI publication, alerts, and selected-pet changes return to the main actor only after a complete validated result exists.
- External processes drain stdout and stderr concurrently before awaiting termination, or inherit/file-redirect output. Waiting while an unread pipe can fill is forbidden.
- Import has explicit compressed/uncompressed byte, entry-count, image-dimension, nesting, and time limits and supports cancellation.
- Texture loading uses an async, session-keyed, byte-bounded LRU cache. In-flight loads for the same resource coalesce. Session replacement invalidates the namespace.
- Rendering never performs synchronous disk reads on the display callback.

## Runtime boundaries

- `PetStore.install` is asynchronous. It performs archive listing, extraction,
  conversion, validation and installation away from the main actor, then
  returns one completely validated installed package.
- Package inspection retains a synchronous primitive for command-line
  validators and unit tests, plus an explicit async entry point for application
  flows. AppKit callers may only use the async entry point.
- Process output is merged into one bounded capture stream and drained before
  termination is awaited. Capture exceeding its configured diagnostic limit
  fails closed instead of growing memory without limit.
- Texture decoding is owned by a renderer-side actor. Its key includes the pet
  session generation and canonical resource URL. Only the latest frame request
  for the current generation may publish to the main-actor view.
- Cache cost is decoded texture bytes, not compressed file bytes. LRU eviction
  occurs before a newly loaded value becomes visible, and a value larger than
  the total budget is returned to its requester without being retained.
- Cancelling a single waiter does not cancel a coalesced load needed by another
  waiter. Replacing a session cancels every load owned by the old cache
  namespace and removes all retained textures.

## Verification

Tests include a large archive whose output exceeds pipe capacity, main-actor responsiveness probes, repeated-frame cache hits, concurrent duplicate loads, eviction under the byte ceiling, cancellation, and session invalidation.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established background import and bounded texture-cache requirements. |
| 2026-07-23 | CHG-20260723-012 | Defined async publication, bounded process capture, decoded-byte LRU and session invalidation boundaries. |
