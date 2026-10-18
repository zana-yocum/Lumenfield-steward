#!/usr/bin/env python3
"""ST-13, NFR-03. Fails the pull request when a Steward Apex class is below the coverage gate.

The org's own rule is 75% across all code. Steward's is stricter: every class and trigger in
force-app at 90% or more, each on its own. This script reads the coverage the org returned with
the check-only deployment (`sf project deploy validate --json`) and compares every class in the
source folder with the gate.

It fails closed. A class the org reported no coverage for counts as 0%, and a result with no
coverage data at all fails the check rather than passing it. Test classes, interfaces and enums
have nothing to cover and are skipped.

Usage: python3 scripts/check_coverage.py validate.json force-app 90
Exit codes: 0 every class meets the gate, 1 at least one doesn't, 2 the input couldn't be read.
"""

import json
import math
import os
import re
import sys
from pathlib import Path

DECLARATION = re.compile(r"\b(class|interface|enum|trigger)\b", re.IGNORECASE)
TEST_ANNOTATION = re.compile(r"@\s*istest\b", re.IGNORECASE)


def strip_comments_and_strings(source):
    """Blanks out comments and string literals, so only code is searched."""
    out = []
    i, n = 0, len(source)
    while i < n:
        two = source[i : i + 2]
        if two == "/*":
            end = source.find("*/", i + 2)
            i = n if end == -1 else end + 2
            out.append(" ")
        elif two == "//":
            end = source.find("\n", i)
            i = n if end == -1 else end
        elif source[i] == "'":
            i += 1
            while i < n and source[i] != "'":
                i += 2 if source[i] == "\\" else 1
            i += 1
            out.append("''")
        else:
            out.append(source[i])
            i += 1
    return "".join(out)


def classify(path):
    """Returns 'gated', 'test', 'interface' or 'enum', and whether the body is empty."""
    code = strip_comments_and_strings(path.read_text(encoding="utf-8-sig"))
    match = DECLARATION.search(code)
    if match is None:
        return "gated", False
    kind = match.group(1).lower()
    if kind in ("interface", "enum"):
        return kind, False
    if kind == "class" and TEST_ANNOTATION.search(code[: match.start()]):
        return "test", False
    opening = code.find("{", match.end())
    body = code[opening + 1 : code.rfind("}")] if opening != -1 else ""
    return "gated", body.strip() == ""


def gated_components(source_dir):
    """Every class and trigger the gate applies to: {name: (path, has_empty_body)}."""
    components = {}
    for path in sorted(source_dir.rglob("*")):
        if path.suffix not in (".cls", ".trigger") or not path.is_file():
            continue
        kind, empty = classify(path)
        if kind == "gated":
            components[path.stem.lower()] = (path, empty)
    return components


def as_list(value):
    """The deploy result holds one object instead of a list when there's only one entry."""
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def reported_coverage(result):
    """{name: (covered, total)} from the deploy result, or None if it has no test results."""
    run = ((result.get("result") or {}).get("details") or {}).get("runTestResult")
    if not run:
        return None
    coverage = {}
    for entry in as_list(run.get("codeCoverage")):
        if entry.get("namespace"):  # managed package code isn't Steward's
            continue
        total = int(entry.get("numLocations") or 0)
        missed = int(entry.get("numLocationsNotCovered") or 0)
        coverage[str(entry.get("name", "")).lower()] = (total - missed, total)
    return coverage


def percent(covered, total):
    """Rounded down to one decimal, so 89.96% shows as 89.9%, not a passing-looking 90.0%."""
    return 100.0 if total == 0 else math.floor(covered * 1000 / total) / 10


def evaluate(components, coverage, gate):
    """One row per component: (name, path, percent or None, covered, total, verdict)."""
    rows = []
    for key, (path, empty) in sorted(components.items()):
        name = path.stem
        if key not in coverage:
            if empty:
                rows.append((name, path, None, 0, 0, "No executable lines"))
            else:
                rows.append((name, path, 0.0, 0, 0, "Not reported"))
            continue
        covered, total = coverage[key]
        passed = total == 0 or covered * 100 >= gate * total
        rows.append(
            (
                name,
                path,
                percent(covered, total),
                covered,
                total,
                "Pass" if passed else "Below gate",
            )
        )
    return rows


def write_summary(rows, gate, failures):
    """Adds the table to the GitHub Actions job summary, when running in Actions."""
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    lines = [
        f"### Apex coverage, {gate:g}% per class (ST-13)",
        "",
        "| Class | Coverage | Lines covered | Result |",
        "|---|---|---|---|",
    ]
    for name, _, pct, covered, total, verdict in rows:
        shown = "n/a" if pct is None else f"{pct:.1f}%"
        lines.append(f"| {name} | {shown} | {covered} of {total} | {verdict} |")
    verdict = f"{failures} below the gate" if failures else "Every class meets the gate"
    lines += ["", f"**{verdict}.**", ""]
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write("\n".join(lines))


def main(argv):
    if len(argv) not in (3, 4):
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    result_file, source_dir = Path(argv[1]), Path(argv[2])
    gate = float(argv[3]) if len(argv) == 4 else 90.0

    components = gated_components(source_dir)
    if not components:
        print(f"No Apex classes or triggers in {source_dir}, so there's no coverage to check.")
        return 0
    try:
        result = json.loads(result_file.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(f"::error::Couldn't read the deployment result {result_file}: {error}")
        return 2
    coverage = reported_coverage(result)
    if coverage is None:
        print(
            f"::error::The deployment result has no test results, so the coverage of "
            f"{len(components)} Apex classes can't be checked. The check fails rather than "
            f"passing unchecked code."
        )
        return 2

    rows = evaluate(components, coverage, gate)
    failures = sum(1 for row in rows if row[5] in ("Below gate", "Not reported"))
    width = max(len(row[0]) for row in rows)
    print(f"Apex coverage, gate {gate:g}% per class (ST-13)\n")
    print(f"  {'Class'.ljust(width)}  Coverage     Lines  Result")
    for name, path, pct, covered, total, verdict in rows:
        shown = "n/a" if pct is None else f"{pct:.1f}%"
        print(f"  {name.ljust(width)}  {shown:>8}  {covered:>4}/{total:<4} {verdict}")
        if verdict == "Below gate":
            print(f"::error file={path}::{name} is at {shown}, below the {gate:g}% gate.")
        elif verdict == "Not reported":
            print(
                f"::error file={path}::The org reported no coverage for {name}, "
                f"so it counts as 0%. Add or fix its tests."
            )
    print(
        f"\n{len(rows)} checked: "
        + (f"{failures} below the gate." if failures else "every class meets the gate.")
    )
    write_summary(rows, gate, failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
