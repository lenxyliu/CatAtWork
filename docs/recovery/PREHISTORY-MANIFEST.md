# Prehistory recovery manifest — 2026-07-23

- CHG: CHG-20260723-001, CHG-20260723-009
- ISSUE: ISSUE-005
- Intended private Release: `prehistory-2026-07-23`
- Local recovery root: `/Users/oops/Documents/CatAtWork-Recovery-2026-07-23`
- Remote repository: `https://github.com/lenxyliu/CatAtWork` (private; created 2026-07-23)
- Remote upload: complete — `https://github.com/lenxyliu/CatAtWork/releases/tag/prehistory-2026-07-23`
- Remote download verification: complete — TR-RECOVERY-20260723-002
- Cleanup authorization: granted by repository owner and executed 2026-07-23
- Git LFS: v3.7.0 installed at `/Users/oops/.local/bin/git-lfs`; clean repository initialized and verified

The cleanup gate is closed. The frozen recovery root, nine Assets archives,
seven DMGs and remote Release remain retention artifacts and must not be
deleted as routine workspace cleanup.

## Frozen legacy Git

| Item | Value |
| --- | --- |
| Path | `/Users/oops/Documents/CatAtWork-Recovery-2026-07-23/legacy-git` |
| File count | 9,658 |
| Allocated size | 2,302,420 KiB (`du -sk`) |
| Integrity | `git fsck --full --no-reflogs` passed; only expected dangling trees/blob reported |
| Per-file checksum manifest | `legacy-git-files.sha256` (9,658 lines; 1,728,662 bytes) |
| Manifest SHA-256 | `62653f98028a600bf5f81d714b65e5bbd58b09062613226335b70a5ac8bb620d` |

Verify without mutating the backup:

```sh
shasum -a 256 /Users/oops/Documents/CatAtWork-Recovery-2026-07-23/legacy-git-files.sha256
(cd / && shasum -a 256 -c /Users/oops/Documents/CatAtWork-Recovery-2026-07-23/legacy-git-files.sha256)
git --git-dir=/Users/oops/Documents/CatAtWork-Recovery-2026-07-23/legacy-git fsck --full --no-reflogs
```

## Recovered Assets trees

The review originally found eight historical states. Recovery found a ninth unique current-state tree and preserves it instead of silently omitting it. File counts below are Git tree files; ZIPs add one directory entry for the `Assets/` prefix.

| Timestamp | Assets tree | Files | ZIP bytes | ZIP SHA-256 | Change from prior tree |
| --- | --- | ---: | ---: | --- | --- |
| 20260721-201646 | `0c1972c1d5a2de2ef15964514096cd9db751c5ae` | 763 | 206,163,139 | `e1cbcaee5ac5646383a0def6c9f66a76e75005f4861b518a48a4219c16c6441a` | first recovered state |
| 20260722-103018 | `c182324e0abb86eaff2703d8763de1c6522c3d01` | 766 | 213,492,508 | `97b28e02d6cd9cd9979a951ee22adfc34d71d3072600d1641e17ef74d82523ce` | 162 files changed |
| 20260722-134935 | `8014ee74d5104ea0a0da3144af5601d9e7a5b6f9` | 955 | 256,621,371 | `15c98eb2ad66b800226ac17621d9a281fe1bee0642bf935c284f431856e3913f` | 262 files changed |
| 20260722-151532 | `6fc01bbb0020471242bc9a0ff8c971980db6b76d` | 959 | 259,997,737 | `3bcf948c9f1aade4a1f911435ac29c2cbf81e4b57116722a42d2269b635307dd` | 721 files changed |
| 20260722-182735 | `54c017511c4a0e46733d422e31585f2063044dc4` | 1,258 | 360,609,015 | `e01d9c5524911a8ef38373375bef9ba39abacd5bcd19ace14df77f0acff7ba56` | 638 files changed |
| 20260722-194954 | `f33c9f93289556bc573ba05b0e6b9676493790a1` | 1,485 | 420,217,713 | `637b029a4504aab700d740d3fad5fa4e775b808871b78dbb9299fa64b50db908` | 252 files changed |
| 20260722-203114 | `65cd552d86736d79d501df513f0b96253424ae8f` | 1,581 | 443,361,780 | `aa3fc753c987ac01b46d0c2704f77c76335cf1188536e719a473528c4b423986` | 96 files changed |
| 20260723-010114 | `358b900649ee79d276ff31a514c58966371de852` | 1,809 | 494,822,421 | `a0d7005595dc452a8332a3ce0d92b94bfb90516c02043ac0462d7d7f39daa8af` | 301 files changed |
| 20260723-101214 | `68cc1a3b2bf20ea0e653473caf83b1ce7cc94420` | 1,809 | 494,258,459 | `06250b1e23761fa701b89a1b2bf150fc7fbb5b8f4f31fa5d80cdbdd4c7166224` | 25 files changed |

Archive naming is `asset-snapshots/assets-<timestamp>-<tree>.zip`. All nine passed `unzip -tqq` locally.

Restore one snapshot into an empty destination:

```sh
mkdir -p /private/tmp/catatwork-assets-restore
unzip /Users/oops/Documents/CatAtWork-Recovery-2026-07-23/asset-snapshots/assets-20260723-101214-68cc1a3b2bf20ea0e653473caf83b1ce7cc94420.zip -d /private/tmp/catatwork-assets-restore
```

## Historical DMGs

Local archive: `/Users/oops/Documents/CatAtWork-Recovery-2026-07-23/release-artifacts/dmgs`. All seven copies were re-hashed after copying and match their sources.

| Artifact | Bytes | SHA-256 | Role |
| --- | ---: | --- | --- |
| `猫上班了-测试版.dmg` | 80,144,806 | `27493718e5ee633c80720fd40a2faa4ab8c29446a240175935861ede34bcfb6a` | historical |
| `猫上班了-1.0.2-测试版.dmg` | 80,640,289 | `7842dcdeeac8e5a45538e2d67f15430065749c03df89c34f4c23769cf07b97ae` | historical |
| `猫上班了-1.0.2-构建4-测试版.dmg` | 80,640,047 | `a2ab882a8473b7086034483ff0425185bd3345ea6fb58e2f669a1a3e251596c2` | historical |
| `猫上班了-1.0.3-构建5-测试版.dmg` | 92,370,536 | `84512f7a2064b49e7bf6e8cfb7ba795f991a4b12209b6e3b2358b3af34f6145c` | historical |
| `猫上班了-1.0.3-构建6-测试版.dmg` | 92,149,416 | `69c6c0977d0f5cd8ef2d6200056e99c25940c1ec7fa2f657303dda1b6d470330` | historical |
| `猫上班了-1.0.3-构建7-测试版.dmg` | 92,152,398 | `a5cdecdd11039b20d420c2f321b9258ba4855955d1a910fe6a3d7645ef6015ae` | historical |
| `猫上班了-1.0.3-构建8-抛掷动画回退版.dmg` | 91,555,924 | `2d603928d1145140deaea25ccf09d5da7365d1998bac2236de9ddeb2aa159e59` | current test candidate; not a signed/notarized release |

Verify an attachment after downloading:

```sh
shasum -a 256 "/path/to/downloaded/猫上班了-1.0.3-构建8-抛掷动画回退版.dmg"
```

## Remote round-trip checklist

- [x] Create private GitHub repository.
- [x] Create private Release/tag `prehistory-2026-07-23` without calling it a product release.
- [x] Upload nine Assets ZIPs and seven DMGs.
- [x] Record repository and Release URLs in TR-RECOVERY-20260723-002.
- [x] Download oldest, latest and largest Assets archives plus build 8 DMG into a new temporary directory.
- [x] Verify byte sizes and SHA-256 against this manifest.
- [x] Present exact cleanup targets and receive explicit owner approval.
- [x] Execute cleanup and verify clean Git/LFS status.

## Remote verification result

The private prerelease contains 16 attachments totaling 3,759,197,559 bytes.
GitHub's server-reported SHA-256 digest for every attachment matched its local
source. The representative round-trip directory
`/private/tmp/CatAtWork-Release-Roundtrip-20260723` contained:

- oldest Assets snapshot `20260721-201646`;
- largest snapshot `20260723-010114`;
- latest/current snapshot `20260723-101214`;
- build 8 DMG.

All four downloaded hashes matched. All three ZIPs passed `unzip -tqq`.

## Authorized cleanup result

Before deletion, checksum-mode `rsync --dry-run` reported no content
difference between workspace `.git` and the frozen `legacy-git` backup.

| Exact workspace target | Before | Result |
| --- | ---: | --- |
| `.git` legacy duplicate | 2,302,436 KiB | deleted; replaced by 158 MiB clean `.git` |
| `.build` | 717,740 KiB | deleted; regenerable |
| `Build` | 754,524 KiB | deleted; regenerable |
| `Resources/DefaultPets` | 78,724 KiB | deleted; 34 files were byte-identical to the retained runtime package |

The duplicate-package aggregate SHA-256 was
`fed6c517ce352b00cb97479a922d897c77417a6f4f5c1110c0e874463b2118b8`
for both trees. The retained runtime source is
`Sources/CatAtWork/Resources/DefaultPet.catpet`.

Post-cleanup checks:

- local `main` and `origin/main` both resolve to
  `340251a25440a2db427e11d247aa3dcab44dd34c`;
- worktree and Git LFS status are clean;
- `git fsck --full` reports no errors;
- `.githooks` and the repository-scoped SSH deploy-key configuration remain
  active;
- frozen `legacy-git` remains 2.2 GiB outside the workspace.
