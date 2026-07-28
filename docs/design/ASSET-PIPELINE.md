# Asset and prehistory pipeline

## Source classes

- Current production: `Assets/CatAtWork/frames`, `identity`, `repairs`, `app-icon`, plus the runtime package under `Sources/CatAtWork/Resources/DefaultPet.catpet`. Production raster data is Git LFS content.
- Generated drafts and bulk QA previews: archived, immutable Release attachments; ignored by Git.
- Historical Assets snapshots and historical DMGs: immutable Release attachments; ignored by Git and listed with byte count and SHA-256 in `docs/recovery/PREHISTORY-MANIFEST.md`.
- Build output: `.build`, `Build`, app bundles, dSYM, DMG and caches are reproducible and ignored.

## Canonical runtime package

`Sources/CatAtWork/Resources/DefaultPet.catpet` is the only runtime default-pet source. Packaging and validation scripts read it or generate it from the formal production frames. `Resources/DefaultPets` must not exist after migration.

## Canonical format-2 authoring

Canonical authoring uses `animation-spec.json` with `contractVersion: 2`.
Every compatible package obeys all of these invariants:

- `pixelsPerBodyUnit` is exactly **220**. It is package-global and no action
  or frame may override it.
- `authoredCanvas` declares one width, height and positive safe margin. Every
  source frame and atlas rectangle has that exact width and height. Alpha must
  stay inside the safe margin.
- Source frames are declared sRGB, straight-alpha RGBA8. An embedded ICC
  profile, another color-space name, implicit mode conversion or color
  transform fails the build. The canonical source-to-atlas operation is an
  identity pixel conversion.
- `authoringScale`, action/frame resize and non-unit `bodyScale` are
  forbidden. `renderOffset` may express authored motion but never changes
  body scale.
- Each frame supplies one anatomical `rootAnchor` and one or more named
  support anchors with explicit contact state. The packaged normalized
  `pivot` is derived only from the authored root.
- `identityRig.views` carries canonical eye centers, ear roots, nose, mouth,
  shoulder, hip, fore/hind-limb joints and tail root; head/mask contours; a
  reference action/frame; and named comparable material ROIs.
- Visible secondary components are forbidden by default at the declared
  alpha/area/connectivity thresholds. A permitted semantic component requires
  one exact frame-scoped exception with review ID, GitHub Issue, owner,
  reviewer, rationale and upper bounds. The builder never deletes pixels.

`Scripts/canonical_asset_contract.py` validates the authoring inputs, uses
exact RGBA paste into the atlas, reopens every emitted atlas and compares the
canonical source/atlas digest. The digest is:

```text
SHA-256(uint32be(width) || uint32be(height) || row-major straight RGBA8)
```

Both source and atlas values are written to the format-2 frame and must be
equal. Repeated builds from equal inputs produce equal manifest and atlas
bytes; paths, timestamps and host order do not enter package content.
Canonical output is written through a distinct staging directory and the
builder refuses an existing destination; it never silently replaces a
production or previously reviewed package.

### B4 source-effect color authoring

Generated effect sheets are pre-authoring inputs, not canonical package
sources. Before a generated pose becomes a fixed-canvas production frame, the
B4 authoring step applies the package-global color rule accepted by ADR-0017:

- one source-effect reference is bound by source-sheet and extracted-frame
  SHA-256 plus recorded light, warm and dark material measurements;
- every material uses the same declared low-frequency source/target weights,
  same-material neighborhood, detail-residual weight, thresholds and
  nearest-integer ties-to-even rounding;
- manual per-action or per-frame tuning is forbidden;
- the accepted source effect must keep identical size and alpha and remain
  within ΔE00 3 in each material after authoring;
- same-material local L* gradient RMS must remain within the declared
  authored/source interval so color continuity cannot be achieved by
  flattening texture; and
- the authored production PNG, not the generated effect sheet, is the
  canonical sRGB source whose bytes are copied identically into the atlas.

Color authoring may change RGB only. It may not change alpha, geometry,
canvas, scale, root/support, identity, pose, components, facing or
source-to-atlas identity.

## Legacy authoring boundary

The accepted asset `2026.07.23.6` and its `animation-spec.json` remain
format-1 legacy inputs until B4 rebuilds the artwork. They are not rewritten
or upgraded by B3.

`Scripts/build_catpet.py` rejects a legacy spec by default. Passing
`--legacy-v1` explicitly reproduces the old `authoringScale`, alpha-derived
pivot and `bodyScale` behavior and emits format 1. This compatibility path is
for controlled reproduction/migration only; it cannot emit format 2 and is
never a release acceptance signal.

## Preservation gate

No old Git object database or historical local artifact may be removed until: external backup integrity passes; archives have local checksums; the private Release upload completes; selected attachments are downloaded again; downloaded checksums match; and the user approves exact deletion targets.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Adopted LFS-current plus immutable-Release-history model and deletion gate. |
| 2026-07-26 | CHG-20260726-005 | Added fixed-canvas format-2 authoring, explicit anchors/identity/color/components, exact pixel round-trip and an explicit legacy-v1 boundary. |
| 2026-07-28 | CHG-20260728-001 | Bound B4 color authoring to the accepted source-effect color/detail oracle while preserving the canonical authored-source-to-atlas identity path. |
