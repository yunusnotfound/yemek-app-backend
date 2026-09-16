#!/usr/bin/env python3
"""Collect one completed profile benchmark from its Flutter/native console log."""

import argparse
import json
from pathlib import Path
import re
import sys


PREFIX = re.compile(r"PHONE_PERFORMANCE_RESULT\s*:?\s*")
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def collect(log_text):
    """Merge per-entry JSON lines, rejecting incomplete, failed or mixed runs."""
    result = {}
    passed = False
    failed = False
    for number, raw in enumerate(log_text.splitlines(), 1):
        line = ANSI.sub("", raw)
        marker = PREFIX.search(line)
        if marker:
            try:
                fragment = json.loads(line[marker.end():])
            except json.JSONDecodeError as error:
                raise ValueError(f"Truncated or invalid result JSON on line {number}") from error
            if not isinstance(fragment, dict) or not fragment:
                raise ValueError(f"Expected a nonempty JSON object on line {number}")
            duplicates = result.keys() & fragment.keys()
            if duplicates:
                raise ValueError("Repeated result keys; use a separate log for each run: "
                                 + ", ".join(sorted(duplicates)))
            result.update(fragment)
        else:
            passed = passed or "All tests passed!" in line
            failed = failed or "Some tests failed" in line or "Test failed." in line

    if failed:
        raise ValueError("The console reports test failure; no successful result was written")
    if not passed:
        raise ValueError("Missing 'All tests passed!'; wait for the complete test log")
    if result.get("complete") is not True:
        raise ValueError("Missing complete=true; partial metrics are not a successful run")
    environment = result.get("environment")
    if not isinstance(environment, dict) or environment.get("profileMode") is not True:
        raise ValueError("Missing environment.profileMode=true; debug measurements are rejected")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="One finished console/drive log")
    parser.add_argument("--output", type=Path, help="New JSON path; defaults to stdout")
    args = parser.parse_args()
    try:
        if args.output and args.output.exists():
            raise ValueError("Output already exists; choose a fresh run filename")
        result = collect(args.log.read_text(encoding="utf-8"))
        rendered = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("x", encoding="utf-8") as stream:
                stream.write(rendered)
            print(f"Validated profile result: {args.output}")
        else:
            sys.stdout.write(rendered)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
