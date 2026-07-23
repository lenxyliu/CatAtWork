# Asynchronous package and texture I/O

## Rules

- Directory inspection, ZIP extraction, path/security checks that touch disk, image decoding/validation, checksumming, and import copies run outside the main actor.
- UI publication, alerts, and selected-pet changes return to the main actor only after a complete validated result exists.
- External processes drain stdout and stderr concurrently before awaiting termination, or inherit/file-redirect output. Waiting while an unread pipe can fill is forbidden.
- Import has explicit compressed/uncompressed byte, entry-count, image-dimension, nesting, and time limits and supports cancellation.
- Texture loading uses an async, session-keyed, byte-bounded LRU cache. In-flight loads for the same resource coalesce. Session replacement invalidates the namespace.
- Rendering never performs synchronous disk reads on the display callback.

## Verification

Tests include a large archive whose output exceeds pipe capacity, main-actor responsiveness probes, repeated-frame cache hits, concurrent duplicate loads, eviction under the byte ceiling, cancellation, and session invalidation.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established background import and bounded texture-cache requirements. |

