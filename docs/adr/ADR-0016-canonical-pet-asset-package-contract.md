# ADR-0016 — Version the canonical pet asset and package contract

- Status: accepted
- Date: 2026-07-26
- CHG: CHG-20260726-005
- ISSUE: ISSUE-015, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026;
  GitHub #9, #11, #12, #16, #17, #21

## Context

The accepted format-1 package can carry one `pixelsPerBodyUnit`, but the
authoring pipeline may first resize individual actions through
`authoringScale`, derive each pivot from changing alpha bounds and then hide
the resize behind `bodyScale = 1`. It does not carry a fixed authored canvas,
an anatomical root/support track, a canonical identity rig, endpoint pixel
signatures, declared color semantics, reviewed component exceptions or
source-to-atlas pixel evidence.

The current production package is a governed legacy artifact with known B1
failures. B3 must define future canonical semantics without silently
rewriting that package or pretending that metadata alone repairs its raster
content.

## Decision

Add `.catpet` format 2 as the canonical contract and retain format 1 as an
explicit legacy-compatibility mode.

A format-2 package:

- uses exactly 220 `pixelsPerBodyUnit` for every frame and prohibits
  action/frame resizing and non-unit `bodyScale`;
- declares one fixed authored canvas and safe margin shared by all frames;
- carries an explicit anatomical `rootAnchor` plus named support/contact
  anchors for every frame; runtime `pivot` must be the normalized root, never
  an alpha-bounds result;
- declares a canonical identity rig containing the required anatomical
  landmarks, head/mask contours, view references and comparable material
  ROIs;
- binds `startPose` and `endPose` to signatures of the actual first and last
  frame pixels, root and support anchors;
- declares sRGB RGBA8 straight-alpha input and uses a deterministic identity
  conversion to atlas pixels;
- forbids material disconnected components by default and permits only
  bounded, Issue-linked, owner-reviewed exceptions;
- records canonical RGBA SHA-256 values for both source and atlas pixels and
  requires them to match.

The canonical authoring builder refuses `authoringScale`, implicit
`bodyScale`, missing anchors/pose signatures and incomplete color/component
metadata. A separate explicit legacy option may reproduce a format-1 build;
it never upgrades or mutates an existing package.

Format-1 import remains supported: positive finite package density is
normalized by the existing runtime scale, `bodyScale` and pivot retain their
legacy meaning, missing poses use the accepted deterministic profiles and
missing canonical metadata is not synthesized or written back. Format 2
fails closed when any canonical field or content invariant is invalid.

## Consequences

B4 can rebuild every production action against one reviewable scale, canvas,
root, identity, pose, color and component system. Silhouette, tail or fur
changes cannot alter root or world scale, and atlas packing cannot hide a
resize. Package generation gains more authored metadata and validation cost.

The current asset `2026.07.23.6` remains byte-for-byte format 1 and retains
its known B2 release failures. B3 does not repair, convert or publish it.
Legacy compatibility is deliberately read-only by default; producing another
legacy package requires an explicit command-line choice.

## Rejected alternatives

- Reinterpreting format 1 in place would silently change accepted package
  semantics and make old packages fail unpredictably.
- Continuing to derive pivots from alpha bounds would keep tail, fur and
  support changes coupled to the world root.
- Allowing arbitrary action density or `bodyScale` in format 2 would preserve
  the same hidden resize path under different field names.
- Automatically deleting disconnected pixels would alter authored content and
  erase evidence instead of failing the package.
