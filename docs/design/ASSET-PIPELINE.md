# Asset and prehistory pipeline

## Source classes

- Current production: `Assets/CatAtWork/frames`, `identity`, `repairs`, `app-icon`, plus the runtime package under `Sources/CatAtWork/Resources/DefaultPet.catpet`. Production raster data is Git LFS content.
- Generated drafts and bulk QA previews: archived, immutable Release attachments; ignored by Git.
- Historical Assets snapshots and historical DMGs: immutable Release attachments; ignored by Git and listed with byte count and SHA-256 in `docs/recovery/PREHISTORY-MANIFEST.md`.
- Build output: `.build`, `Build`, app bundles, dSYM, DMG and caches are reproducible and ignored.

## Canonical runtime package

`Sources/CatAtWork/Resources/DefaultPet.catpet` is the only runtime default-pet source. Packaging and validation scripts read it or generate it from the formal production frames. `Resources/DefaultPets` must not exist after migration.

## Preservation gate

No old Git object database or historical local artifact may be removed until: external backup integrity passes; archives have local checksums; the private Release upload completes; selected attachments are downloaded again; downloaded checksums match; and the user approves exact deletion targets.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Adopted LFS-current plus immutable-Release-history model and deletion gate. |

