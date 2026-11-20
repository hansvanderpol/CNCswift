#!/usr/bin/env python3
"""Fail when a public Swift declaration lacks an immediately preceding DocC comment.

Constitution V requires DocC on public API, covering preconditions, thrown errors and
concurrency expectations where relevant. This gate checks presence and placement; the
content is reviewed in code review. Attributes (for example ``@MainActor``) may sit
between the DocC comment and the declaration.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

MODIFIERS = (
    r"final|class|static|mutating|nonmutating|override|required|convenience|"
    r"indirect|open|weak|unowned|inout|private|internal|fileprivate|package|"
    r"nonisolated|async|throws|rethrows|sendable|escaping|some|any"
)
DECLARATION_KINDS = (
    r"struct|class|enum|protocol|actor|func|var|let|init|deinit|extension|"
    r"typealias|subscript|associatedtype|operator"
)
ATTRIBUTE = r"@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?"
DECLARATION = re.compile(
    rf"^\s*(?:{ATTRIBUTE}\s+)*(?:(?:{MODIFIERS})\s+)*public\s+"
    rf"(?:(?:{MODIFIERS})|\({{\s*(?:set|get)\s*}}\))*"
    rf"(?:\s+(?:{MODIFIERS}))*\s*(?:{DECLARATION_KINDS})\b"
)


def has_docc(lines: list[str], index: int) -> bool:
    """True when line ``index`` is preceded by a DocC comment (allowing attributes)."""
    cursor = index - 1
    while cursor >= 0 and lines[cursor].strip().startswith("@"):
        cursor -= 1
    if cursor < 0:
        return False

    stripped = lines[cursor].strip()
    if stripped.startswith("///"):
        # A contiguous /// block is one DocC comment; blank lines break the block.
        while cursor >= 0 and lines[cursor].strip().startswith("///"):
            cursor -= 1
        return True

    if stripped.endswith("*/"):
        while cursor >= 0 and not lines[cursor].strip().startswith("/*"):
            cursor -= 1
        return cursor >= 0 and lines[cursor].strip().startswith("/**")

    return False


def check_file(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    findings: list[str] = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith(("//", "/*", "*")):
            continue
        if DECLARATION.match(line) and not has_docc(lines, index):
            findings.append(f"{path}:{index + 1}: {stripped}")
    return findings


def swift_files(paths: list[str]) -> list[Path]:
    roots = [Path(p) for p in paths] if paths else [Path("Packages"), Path("App")]
    files: set[Path] = set()
    for root in roots:
        if root.is_file() and root.suffix == ".swift":
            files.add(root)
        elif root.is_dir():
            files.update(root.rglob("*.swift"))
    # SwiftPM writes generated XCTest entry points under .build; they are not our API.
    return sorted(p for p in files if ".build" not in p.parts and "Tests" not in p.parts)


def main() -> int:
    paths = sys.argv[1:]
    findings: list[str] = []
    files = swift_files(paths)
    for path in files:
        # Test targets are not public API; the gate covers shipping sources only.
        if "/Tests/" in str(path) or str(path).endswith("Tests.swift"):
            continue
        findings.extend(check_file(path))

    if findings:
        print(f"DocC gate: {len(findings)} public declaration(s) without a DocC comment:")
        for finding in findings:
            print(f"  {finding}")
        return 1

    print(f"DocC gate: PASS ({len(files)} Swift files checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
