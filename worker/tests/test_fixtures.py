import json
import re
from pathlib import Path

FIXTURES = Path(__file__).resolve().parents[2] / "shared" / "chord_fixtures.json"


# Phase 0 checks the shared file's shape; phase 1 runs the Python parser against it.
def test_fixture_file_shape():
    data = json.loads(FIXTURES.read_text(encoding="utf-8"))
    assert data["version"] == 1
    assert data["valid"] and data["invalid"]
    for case in data["valid"]:
        assert case["input"] and case["canonical"]
        assert re.fullmatch(r"[A-G][#b]?", case["root"])
    assert not {c["input"] for c in data["valid"]} & set(data["invalid"])
