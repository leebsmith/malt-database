#!/usr/bin/env python3
"""Validate a maltster's intermediate JSON against its schema.

Usage: validate.py <maltster>

Reads data/maltsters/<maltster>.json, validates every entry against
schema/<maltster>.schema.json, and exits non-zero (with a message per
violation) if anything fails.
"""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent

MALTSTERS_DIR = ROOT / "data" / "maltsters"
SCHEMA_DIR = ROOT / "schema"


def load(path: Path):
    with path.open() as f:
        return json.load(f)


def main(maltster: str) -> int:
    data_path = MALTSTERS_DIR / f"{maltster}.json"
    schema_path = SCHEMA_DIR / f"{maltster}.schema.json"

    if not data_path.exists():
        print(f"error: {data_path} not found; run `make {maltster}` first", file=sys.stderr)
        return 1
    if not schema_path.exists():
        print(f"error: {schema_path} not found", file=sys.stderr)
        return 1

    validator = Draft202012Validator(load(schema_path))
    entries = load(data_path)

    failed = False
    for i, entry in enumerate(entries):
        for err in validator.iter_errors(entry):
            failed = True
            print(f"{maltster}[{i}] ({entry.get('name', '?')}): {err.message}", file=sys.stderr)

    if failed:
        print(f"validation failed: {data_path}", file=sys.stderr)
        return 1

    print(f"validated {len(entries)} entries -> {data_path}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
