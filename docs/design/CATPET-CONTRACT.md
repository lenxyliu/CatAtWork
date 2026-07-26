# `.catpet` package contract

## Contract versions

| `formatVersion` | Semantics | Compatibility |
| --- | --- | --- |
| 1 | Legacy variable canvas/pivot and optional per-frame `bodyScale` | Read-only compatible; missing poses use deterministic legacy profiles; canonical metadata is not synthesized or written back |
| 2 | Canonical asset/package contract in ADR-0016 | Every canonical field and content invariant is required and fails closed |

Unsupported versions fail explicitly. Import never silently converts a
format-1 directory or overwrites its manifest/atlases.

## Supported contract

- In format 1, `pixelsPerBodyUnit` is finite and positive and defines the world scale shared by every frame. Runtime canvas scale is
  `userScale * 220 / pixelsPerBodyUnit`, so equivalent pets authored at
  different pixel densities occupy the same desktop size.
- In format 2, `pixelsPerBodyUnit` is exactly 220. `bodyScale` is absent or
  exactly 1; an action/frame density or resize override is invalid.
- Animation IDs are package capabilities. Exact lookup never falls back.
  Runtime intent maps through the session's semantic fallback table before it
  enters the action queue; an unresolved optional intent is suppressed and
  reported as unavailable.
- Every animation declares or derives a valid `startPose` and `endPose`; pose
  names belong to `seated`, `standing`, `lying`, `hanging`, or `airborne`.
  Missing legacy values use deterministic built-in profiles, with unknown
  legacy animations defaulting to `seated -> seated`.
- `nextAnimation`, when present, points to a real animation and is honored
  after a one-shot completes only when no queued or atomic runtime transition
  has already claimed completion.
- A missing optional capability follows a documented fallback table. It must never silently turn into idle merely because a lookup failed.
- Required baseline capability: `idle`. Interactive/physical capabilities may be declared unsupported; UI and behavior selection must then not offer them.
- `collisionRect` is preferred. If absent, hit testing falls back to `trimRect`, not the full transparent canvas.

## Canonical format-2 metadata

### Canvas, root and support

`authoredCanvas` contains one positive `width`, `height` and `safeMargin`.
Every frame `sourceSize` and `textureRect` uses that exact size. Visible alpha
must remain inside the margin.

Each frame contains:

- `rootAnchor`: anatomical body root in authored-canvas pixels;
- `supportAnchors`: unique named pixel points plus a Boolean `contact`;
- `pivot`: exactly `rootAnchor / authoredCanvas.size`;
- optional `renderOffset`: authored displacement relative to the shared root;
- equal `sourcePixelSHA256` and `atlasPixelSHA256`.

Root/support points must be finite and inside the canvas. Tail, fur, alpha
bounds, non-support limbs and silhouette extent do not participate in root or
world-scale calculation.

### Identity and comparable material

`identityRig.views` defines one or more comparable views. Each view names an
actual reference action/frame and contains at least:

- left/right eye centers and ear roots;
- nose and mouth;
- shoulder and hip;
- left/right forelimb and hindlimb joints;
- tail root;
- `headOutline` and `faceMaskOutline` polygons; and
- one or more named `materialROIs`.

Every point/ROI lies inside the authored canvas. Missing required landmarks,
contours, reference frames or material ROIs reject the package. B2/B4
comparison evidence uses the view ID and these governed ROIs; global resize or
whole-frame color averages cannot substitute for the identity rig.

### Endpoint pose signatures

Format 2 requires `startPose`, `endPose`, `startPoseSignature` and
`endPoseSignature` for every animation. A signature binds:

- the declared pose;
- exact first/last zero-based frame index;
- the endpoint atlas pixel digest;
- the endpoint anatomical root; and
- the sorted IDs of support anchors whose `contact` state is true.

The signature must exactly match the referenced frame. Changing pixels,
anchors, support contact or a pose declaration without regenerating/reviewing
the signature fails closed.

### Color and alpha

`colorSpace` is exactly:

```json
{
  "name": "sRGB",
  "pixelFormat": "RGBA8",
  "alphaMode": "straight",
  "conversion": "identity"
}
```

Canonical source PNGs must already satisfy that declaration; another
declared space, implicit conversion or embedded ICC profile is invalid. Atlas
packing preserves straight RGBA bytes exactly and strips no meaningful pixel
content.

### Disconnected components

`componentPolicy.default` is `forbid`, connectivity is 8, and alpha/area
thresholds are explicit. A secondary material component is accepted only
when exactly one `exceptions` row matches its action/frame and bounds. Each
row carries a stable review ID, GitHub Issue, owner, reviewer, rationale,
exact zero-based frames, maximum component count and maximum secondary area.
The frame binds the same review ID. Missing, broad, unused, duplicate or
over-budget exceptions reject the package.

### Pixel/alpha round-trip

The canonical digest is SHA-256 over big-endian width/height followed by
row-major straight RGBA8 bytes. The builder hashes each fixed-canvas source,
packs without resize or resampling, reopens the emitted atlas, extracts the
declared rectangle and requires byte/digest equality. Package validation
recomputes each atlas digest plus safe-margin and component policy before
acceptance.

## Semantic fallback table

| Requested capability | Ordered fallback | If unavailable |
| --- | --- | --- |
| `runLeft`, `runRight` | same-direction `walkLeft`, `walkRight` | suppress motion |
| `earPet`, `chinPet`, `backPet`, `bellyPet` | `petting`, then `curious` | suppress reaction |
| `wave` | `curious` | suppress reaction |
| `wakeUp` | `getUp` | suppress wake animation |
| `getUp` | `wakeUp` | suppress recovery animation |
| all other optional IDs | none | suppress |

Physical grab/throw is offered only if `pickup`, `thrown`, and `landing` all
exist exactly. Pose routing uses only authored/derived canonical bridge
capabilities; if no legal route exists, the target is suppressed rather than
starting from an incompatible pose.

## Session load

Inspect and validate all metadata and referenced resources before publishing a
session. Publishing increments a session generation and atomically resets:
behavior/pose/queue, player frame time, physics velocity/impact, drag samples
and ownership, pointer recognizer/chase, gaze/petting/direction state,
autonomy/roam timers, deferred events, current frame and renderer cache
namespace. The current window anchor and global system context may be
preserved. A failed load preserves the previous valid session.

## Compatibility

Format-1 packages retain their accepted semantics:

- finite positive legacy density remains runtime-normalized;
- legacy `bodyScale` in 0.5–3.0 and stored `pivot` are honored;
- missing poses use deterministic per-animation defaults, with an unknown
  animation deriving `seated -> seated`;
- missing root/support, pose signatures, identity, canvas, color and component
  metadata are not synthesized and never written back; and
- unknown runtime behaviors are reported as unavailable while malformed
  references are rejected.

Legacy `authoringScale` is not a package field. The authoring builder permits
it only with explicit `--legacy-v1`, preserving a reviewable reproduction
path without silently upgrading the result. Migration to format 2 requires
new fixed-canvas source frames and authored canonical metadata; it is the B4
asset rebuild, not an import-time rewrite.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Defined capabilities, pose/next semantics, scale, fallback and session reset. |
| 2026-07-23 | CHG-20260723-011 | Specified exact lookup, fallback/suppression, pose vocabulary, density-normalized scale, next-action ownership, trim hit bounds and atomic session reset. |
| 2026-07-26 | CHG-20260726-005 | Added versioned canonical format-2 canvas/scale, roots/supports, identity rig, endpoint signatures, sRGB/component policy, pixel round-trip and explicit format-1 migration behavior. |
