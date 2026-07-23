#!/usr/bin/env python3
"""Validate repository traceability records and test-content freshness.

The checker intentionally uses only the Python standard library. It is run by
the local pre-commit hook and by GitHub Actions; CI is authoritative.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
from typing import Iterable, Sequence


RECORD_ID = {
    "issue": re.compile(r"\bISSUE-(?:\d{3}|LEGACY-\d{3})\b"),
    "bc": re.compile(r"\bBC-(?:\d{3}|LEGACY-\d{3})\b"),
    "adr": re.compile(r"\bADR-\d{4}\b"),
    "tr": re.compile(r"\bTR-[A-Z0-9-]+\b"),
    "chg": re.compile(r"\bCHG-\d{8}-\d{3}\b"),
}

CHANGE_HEADINGS = (
    "## Purpose",
    "## Before: badcase and risk",
    "## Design impact",
    "## Changes",
    "## Compatibility",
    "## Test evidence",
    "## Rollback",
    "## Revision log",
)
BADCASE_HEADINGS = (
    "## Preconditions",
    "## Reproduction",
    "## Expected",
    "## Actual",
    "## Root cause",
    "## Impact",
    "## Status timeline",
)
TEST_HEADINGS = (
    "## Tested content",
    "## Commands",
    "## Passed",
    "## Failed",
    "## Skipped",
    "## Failure analysis",
    "## Evidence",
    "## Retrospective",
)

EXACT_GOVERNED = {
    ".gitattributes",
    ".gitignore",
    "Package.swift",
    "Package.resolved",
}
GOVERNED_ROOTS = (
    "Sources/",
    "Tests/",
    "Scripts/",
    "Config/",
    "Schemas/",
    ".github/workflows/",
    ".githooks/",
    "Assets/CatAtWork/frames/",
    "Assets/CatAtWork/identity/",
    "Assets/CatAtWork/repairs/",
    "Assets/CatAtWork/app-icon/",
)
EXCLUDED_PARTS = {".git", ".build", "Build", "__pycache__", ".governance-cache"}
FORBIDDEN_TRACKED = (
    ".build/",
    "Build/",
    "Assets/CatAtWork/generated/",
    "Assets/CatAtWork/qa/",
    "Resources/DefaultPets/",
)
IMMUTABLE_PREFIXES = (
    "docs/adr/ADR-",
    "docs/changes/CHG-",
    "docs/test-runs/TR-",
    "docs/audits/AUDIT-",
)
FROZEN_FILES = {"ISSUE-CLASSIFICATION.md", "COMPLETION-AUDIT.md"}
PRODUCTION_BINARY_PREFIXES = (
    "Assets/CatAtWork/frames/",
    "Assets/CatAtWork/identity/",
    "Assets/CatAtWork/repairs/",
    "Assets/CatAtWork/app-icon/",
    "Sources/CatAtWork/Resources/",
)
PRODUCTION_BINARY_SUFFIXES = {".png", ".icns"}


@dataclasses.dataclass(frozen=True)
class Change:
    status: str
    path: str


def run_git(root: Path, args: Sequence[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=root, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=check,
    )


def normalize(path: str) -> str:
    normalized = path.replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized.lstrip("/")


def is_governed(path: str) -> bool:
    path = normalize(path)
    return path in EXACT_GOVERNED or path.startswith(GOVERNED_ROOTS)


def is_production_binary(path: str) -> bool:
    path = normalize(path)
    return path.endswith(tuple(PRODUCTION_BINARY_SUFFIXES)) and path.startswith(PRODUCTION_BINARY_PREFIXES)


def iter_governed_files(root: Path) -> Iterable[Path]:
    candidates: set[Path] = set()
    for exact in EXACT_GOVERNED:
        path = root / exact
        if path.is_file():
            candidates.add(path)
    roots = {prefix.split("/", 1)[0] for prefix in GOVERNED_ROOTS}
    roots.add(".github")
    roots.add(".githooks")
    for top in roots:
        start = root / top
        if not start.exists():
            continue
        for path in start.rglob("*"):
            if not path.is_file() or any(part in EXCLUDED_PARTS for part in path.parts):
                continue
            relative = path.relative_to(root).as_posix()
            if is_governed(relative):
                candidates.add(path)
    yield from sorted(candidates, key=lambda item: item.relative_to(root).as_posix())


def content_digest(root: Path) -> str:
    aggregate = hashlib.sha256()
    for path in iter_governed_files(root):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        file_hash = hashlib.sha256(path.read_bytes()).digest()
        aggregate.update(relative)
        aggregate.update(b"\0")
        aggregate.update(file_hash)
        aggregate.update(b"\0")
    return aggregate.hexdigest()


def parse_metadata(text: str) -> dict[str, str]:
    metadata: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^- ([A-Za-z][A-Za-z0-9 /-]*):\s*(.*?)\s*$", line)
        if match:
            metadata[match.group(1)] = match.group(2)
    return metadata


def ids(value: str, kind: str) -> list[str]:
    return RECORD_ID[kind].findall(value or "")


def read_text(root: Path, path: str, errors: list[str]) -> str:
    try:
        return (root / path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"cannot read {path}: {exc}")
        return ""


def all_changes(root: Path) -> list[Change]:
    excluded_prefixes = (".git/", ".build/", "Build/", "Assets/CatAtWork/generated/", "Assets/CatAtWork/qa/")
    changes: list[Change] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        if any(part in EXCLUDED_PARTS for part in path.parts) or relative.startswith(excluded_prefixes):
            continue
        changes.append(Change("A", relative))
    return sorted(changes, key=lambda item: item.path)


def parse_name_status(raw: str) -> list[Change]:
    fields = raw.split("\0")
    changes: list[Change] = []
    index = 0
    while index < len(fields) and fields[index]:
        status = fields[index]
        index += 1
        if status.startswith(("R", "C")):
            if index + 1 >= len(fields):
                break
            index += 1  # old path
            path = fields[index]
            index += 1
        else:
            if index >= len(fields):
                break
            path = fields[index]
            index += 1
        changes.append(Change(status[0], normalize(path)))
    return changes


def git_changes(root: Path, base: str | None, staged: bool) -> list[Change]:
    if staged:
        result = run_git(root, ["diff", "--cached", "--name-status", "-z", "--find-renames"])
    elif base:
        result = run_git(root, ["diff", "--name-status", "-z", "--find-renames", f"{base}...HEAD"])
    else:
        raise ValueError("a base ref or --staged is required")
    return parse_name_status(result.stdout)


def validate_required_headings(path: str, text: str, headings: Sequence[str], errors: list[str]) -> None:
    for heading in headings:
        if heading not in text:
            errors.append(f"{path}: missing required heading `{heading}`")


def record_exists(root: Path, record_id: str, kind: str) -> bool:
    if kind == "issue":
        for path in (root / "docs/issues").glob("*.md"):
            if record_id in path.read_text(encoding="utf-8"):
                return True
        return False
    directories = {
        "bc": root / "docs/issues/badcases",
        "adr": root / "docs/adr",
        "tr": root / "docs/test-runs",
    }
    directory = directories[kind]
    return directory.exists() and any(record_id in path.name or record_id in path.read_text(encoding="utf-8") for path in directory.glob("*.md"))


def test_record_for(root: Path, test_id: str) -> Path | None:
    directory = root / "docs/test-runs"
    if not directory.exists():
        return None
    return next((path for path in directory.glob("*.md") if test_id in path.name), None)


def tracked_files(root: Path) -> list[str]:
    if not (root / ".git").exists():
        return []
    result = run_git(root, ["ls-files", "-z"], check=False)
    if result.returncode != 0:
        return []
    return [normalize(item) for item in result.stdout.split("\0") if item]


def validate_lfs_and_forbidden(root: Path, errors: list[str]) -> None:
    for path in tracked_files(root):
        if path.startswith(FORBIDDEN_TRACKED) or path.endswith((".dmg", ".app", ".dSYM")):
            errors.append(f"forbidden generated/history path is tracked: {path}")
        if not is_production_binary(path):
            continue
        attr = run_git(root, ["check-attr", "filter", "--", path], check=False).stdout.strip()
        if not attr.endswith(": lfs"):
            errors.append(f"production binary is not configured for Git LFS: {path}")
        blob = run_git(root, ["show", f"HEAD:{path}"], check=False)
        if blob.returncode == 0 and not blob.stdout.startswith("version https://git-lfs.github.com/spec/v1"):
            errors.append(f"tracked production binary is a full Git blob, not an LFS pointer: {path}")


def validate_repository(root: Path, changes: Sequence[Change], trivial: bool = False) -> list[str]:
    errors: list[str] = []
    changed = {change.path for change in changes if change.status != "D"}

    if trivial:
        invalid = sorted(path for path in changed if Path(path).suffix.lower() != ".md")
        if invalid:
            errors.append("governance:trivial is illegal for non-Markdown paths: " + ", ".join(invalid))
        return errors

    for change in changes:
        if change.path in FROZEN_FILES and change.status != "A":
            errors.append(f"frozen baseline must not be modified: {change.path}")
        if change.path.startswith(IMMUTABLE_PREFIXES) and change.status not in {"A"}:
            errors.append(f"immutable record must be superseded, not modified/deleted: {change.path}")
        if change.status == "D" and change.path.startswith(("docs/issues/", "docs/recovery/")):
            errors.append(f"historical evidence must not be deleted: {change.path}")

    nontrivial = sorted(change.path for change in changes if change.status != "D" and is_governed(change.path))
    added_chgs = sorted(
        change.path for change in changes
        if change.status == "A" and change.path.startswith("docs/changes/CHG-") and change.path.endswith(".md")
    )
    if nontrivial and not added_chgs:
        errors.append("governed content changed without a new CHG record")

    current_digest = content_digest(root)
    for chg_path in added_chgs:
        text = read_text(root, chg_path, errors)
        metadata = parse_metadata(text)
        validate_required_headings(chg_path, text, CHANGE_HEADINGS, errors)
        for field in ("Status", "Change-Type", "Strategic-Change", "Owner", "Created", "ISSUE", "BC", "ADR", "Design", "TR"):
            if not metadata.get(field):
                errors.append(f"{chg_path}: missing metadata `{field}`")

        change_type = metadata.get("Change-Type", "").lower()
        issue_ids = ids(metadata.get("ISSUE", ""), "issue")
        bc_ids = ids(metadata.get("BC", ""), "bc")
        adr_ids = ids(metadata.get("ADR", ""), "adr")
        tr_ids = ids(metadata.get("TR", ""), "tr")

        for record_id in issue_ids:
            if not record_exists(root, record_id, "issue"):
                errors.append(f"{chg_path}: referenced issue does not exist: {record_id}")
        for record_id in bc_ids:
            if not record_exists(root, record_id, "bc"):
                errors.append(f"{chg_path}: referenced badcase does not exist: {record_id}")
        for record_id in adr_ids:
            if not record_exists(root, record_id, "adr"):
                errors.append(f"{chg_path}: referenced ADR does not exist: {record_id}")

        if change_type in {"fix", "optimization"}:
            if not issue_ids:
                errors.append(f"{chg_path}: fixes/optimizations require ISSUE references")
            if not bc_ids:
                errors.append(f"{chg_path}: fixes/optimizations require BC references")

        strategic = metadata.get("Strategic-Change", "").lower()
        if strategic not in {"yes", "no"}:
            errors.append(f"{chg_path}: Strategic-Change must be yes or no")
        if strategic == "yes":
            changed_designs = [path for path in changed if path.startswith("docs/design/") and path.endswith(".md")]
            added_adrs = [path for path in changed if path.startswith("docs/adr/ADR-") and path.endswith(".md")]
            if not changed_designs:
                errors.append(f"{chg_path}: strategic change requires a design-document update")
            if not added_adrs or not adr_ids:
                errors.append(f"{chg_path}: strategic change requires a new linked ADR")
            chg_id_match = RECORD_ID["chg"].search(text)
            if chg_id_match:
                chg_id = chg_id_match.group(0)
                for design_path in changed_designs:
                    if chg_id not in read_text(root, design_path, errors):
                        errors.append(f"{design_path}: revision log does not reference {chg_id}")

        if nontrivial:
            if not tr_ids:
                errors.append(f"{chg_path}: governed changes require a passing TR reference")
            passing_fresh = False
            for test_id in tr_ids:
                path = test_record_for(root, test_id)
                if path is None:
                    errors.append(f"{chg_path}: referenced TR does not exist: {test_id}")
                    continue
                tr_text = path.read_text(encoding="utf-8")
                tr_meta = parse_metadata(tr_text)
                validate_required_headings(path.relative_to(root).as_posix(), tr_text, TEST_HEADINGS, errors)
                for field in ("Status", "Date", "Content-SHA256", "Commit/Tree", "System", "Xcode", "Swift", "ISSUE", "BC", "CHG"):
                    if not tr_meta.get(field):
                        errors.append(f"{path.relative_to(root)}: missing metadata `{field}`")
                if tr_meta.get("Status", "").lower() == "pass" and tr_meta.get("Content-SHA256") == current_digest:
                    passing_fresh = True
            if tr_ids and not passing_fresh:
                errors.append(f"{chg_path}: no referenced passing TR matches current digest {current_digest}")

    for path in sorted(changed):
        if path.startswith("docs/issues/badcases/BC-") and path.endswith(".md"):
            text = read_text(root, path, errors)
            metadata = parse_metadata(text)
            validate_required_headings(path, text, BADCASE_HEADINGS, errors)
            for field in ("Status", "ISSUE", "First observed", "Affected versions", "Fixed versions", "Regression test", "Automated evidence", "Device evidence"):
                if not metadata.get(field):
                    errors.append(f"{path}: missing metadata `{field}`")

    validate_lfs_and_forbidden(root, errors)
    return errors


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command")
    subparsers.add_parser("digest", help="print the governed-content SHA-256")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base", help="merge base or base commit for a PR diff")
    parser.add_argument("--staged", action="store_true", help="validate the staged diff")
    parser.add_argument("--all", action="store_true", help="treat the full current tree as a new baseline")
    args = parser.parse_args(argv)
    root = args.root.resolve()

    if args.command == "digest":
        print(content_digest(root))
        return 0

    if args.all:
        changes = all_changes(root)
    else:
        try:
            changes = git_changes(root, args.base, args.staged)
        except (ValueError, subprocess.CalledProcessError) as exc:
            parser.error(str(exc))

    trivial = os.environ.get("GOVERNANCE_TRIVIAL", "").lower() in {"1", "true", "yes"}
    errors = validate_repository(root, changes, trivial=trivial)
    if errors:
        print("Governance check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Governance check passed for {len(changes)} changed paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
