#!/usr/bin/env python3
"""
Structural validator for zenclip-bugcard/1 (stdlib only).
Mirrors agents_ram/zenclip-bug-forensics/schemas/zenclip-bugcard-1.schema.json
critical rules — not a full JSON Schema engine.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

REPORT_ID = re.compile(r"^zc_[A-Za-z0-9_-]{16,24}$")
SHA256_FP = re.compile(r"^sha256:[a-f0-9]{64}$")
SHA256_HEX = re.compile(r"^[a-f0-9]{64}$")

SEVERITY = frozenset({"unusable", "sometimes", "minor"})
SURFACE = frozenset(
    {"cursor_ide", "cursor_cli", "background_agent", "bugbot", "other"}
)
FREQUENCY = frozenset({"always", "often", "sometimes", "once"})
RECORD_TYPES = frozenset({"section", "pass", "warn", "fail", "info", "status"})
ARTIFACT_ROLES = frozenset(
    {
        "screenshot_primary",
        "screenshot_crop",
        "infograph",
        "bundle_json",
        "log_tail",
        "overflow_blob",
    }
)

# Pre-redaction export policy (TRUST_TOUCHPOINTS G1 / T4)
SECRET_PATTERNS = [
    re.compile(r"ghp_[A-Za-z0-9]{20,}", re.I),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}", re.I),
    re.compile(r"-----BEGIN [A-Z ]+ PRIVATE KEY-----"),
    re.compile(r"sk_live_[A-Za-z0-9]{10,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
]


class ValidationError(Exception):
    pass


def _expect_keys(obj: dict[str, Any], keys: set[str], label: str, *, exact: bool) -> None:
    extra = set(obj.keys()) - keys
    missing = keys - set(obj.keys())
    if missing:
        raise ValidationError(f"{label}: missing keys {sorted(missing)}")
    if exact and extra:
        raise ValidationError(f"{label}: unexpected keys {sorted(extra)}")


def _validate_hydration_record(rec: Any, idx: int) -> None:
    if not isinstance(rec, dict):
        raise ValidationError(f"hydration.records[{idx}] must be an object")
    _expect_keys(
        rec,
        {"type", "key", "value"},
        f"hydration.records[{idx}]",
        exact=True,
    )
    if rec["type"] not in RECORD_TYPES:
        raise ValidationError(f"hydration.records[{idx}].type invalid")
    for field in ("key", "value"):
        if not isinstance(rec[field], str):
            raise ValidationError(f"hydration.records[{idx}].{field} must be string")


def _validate_artifact(art: Any, idx: int) -> None:
    if not isinstance(art, dict):
        raise ValidationError(f"artifacts[{idx}] must be an object")
    art_allowed = {"role", "media_type", "sha256", "path", "bytes"}
    _expect_keys(
        art,
        {"role", "media_type", "sha256", "path"},
        f"artifacts[{idx}]",
        exact=False,
    )
    extra_art = set(art.keys()) - art_allowed
    if extra_art:
        raise ValidationError(f"artifacts[{idx}]: unexpected keys {sorted(extra_art)}")
    if art["role"] not in ARTIFACT_ROLES:
        raise ValidationError(f"artifacts[{idx}].role invalid")
    if not SHA256_HEX.match(art["sha256"]):
        raise ValidationError(f"artifacts[{idx}].sha256 pattern")
    if not isinstance(art["path"], str) or art["path"].startswith("/"):
        raise ValidationError(f"artifacts[{idx}].path must be relative basename-style")


def validate_bugcard(doc: Any) -> None:
    if not isinstance(doc, dict):
        raise ValidationError("root must be object")
    allowed_top = {
        "schema",
        "report_id",
        "identity_fingerprint",
        "created_at",
        "updated_at",
        "revision",
        "triage",
        "repro",
        "hydration",
        "cursor_escalation",
        "artifacts",
        "exports",
        "redaction",
    }
    required_top = {
        "schema",
        "report_id",
        "identity_fingerprint",
        "created_at",
        "revision",
        "triage",
        "repro",
        "hydration",
        "artifacts",
        "redaction",
    }
    _expect_keys(doc, required_top, "root", exact=False)
    extra_top = set(doc.keys()) - allowed_top
    if extra_top:
        raise ValidationError(f"root: unexpected keys {sorted(extra_top)}")
    if doc.get("schema") != "zenclip-bugcard/1":
        raise ValidationError("schema must be zenclip-bugcard/1")
    if not REPORT_ID.match(doc["report_id"]):
        raise ValidationError("report_id pattern")
    if not SHA256_FP.match(doc["identity_fingerprint"]):
        raise ValidationError("identity_fingerprint pattern")
    if not isinstance(doc["created_at"], str) or "T" not in doc["created_at"]:
        raise ValidationError("created_at must be ISO date-time string")
    if not isinstance(doc["revision"], int) or doc["revision"] < 1:
        raise ValidationError("revision must be integer >= 1")

    triage = doc["triage"]
    triage_allowed = {
        "title_suggested",
        "severity_user",
        "bug_class",
        "product_surface",
        "forum_template_version",
    }
    _expect_keys(
        triage,
        {"title_suggested", "severity_user", "bug_class", "product_surface"},
        "triage",
        exact=False,
    )
    extra_triage = set(triage.keys()) - triage_allowed
    if extra_triage:
        raise ValidationError(f"triage: unexpected keys {sorted(extra_triage)}")
    if triage["severity_user"] not in SEVERITY:
        raise ValidationError("triage.severity_user enum")
    if triage["product_surface"] not in SURFACE:
        raise ValidationError("triage.product_surface enum")

    repro = doc["repro"]
    repro_allowed = {"steps", "expected", "actual", "frequency", "user_note"}
    _expect_keys(repro, {"steps", "expected", "actual", "frequency"}, "repro", exact=False)
    extra_repro = set(repro.keys()) - repro_allowed
    if extra_repro:
        raise ValidationError(f"repro: unexpected keys {sorted(extra_repro)}")
    if not isinstance(repro["steps"], list) or len(repro["steps"]) > 20:
        raise ValidationError("repro.steps")
    if repro["frequency"] not in FREQUENCY:
        raise ValidationError("repro.frequency enum")

    hyd = doc["hydration"]
    _expect_keys(
        hyd,
        {"vectors_run", "vectors_failed", "records"},
        "hydration",
        exact=True,
    )
    for i, rec in enumerate(hyd["records"]):
        _validate_hydration_record(rec, i)
    for i, fail in enumerate(hyd["vectors_failed"]):
        _expect_keys(fail, {"vector", "reason"}, f"hydration.vectors_failed[{i}]", exact=True)

    for i, art in enumerate(doc["artifacts"]):
        _validate_artifact(art, i)

    red = doc["redaction"]
    _expect_keys(red, {"rules_applied", "secrets_detected"}, "redaction", exact=True)
    if not isinstance(red["secrets_detected"], int) or red["secrets_detected"] < 0:
        raise ValidationError("redaction.secrets_detected")


def scan_export_secrets(doc: dict[str, Any]) -> list[str]:
    """Policy layer: block obvious secrets in export-facing string fields."""
    hits: list[str] = []

    def check_string(path: str, value: str) -> None:
        for pat in SECRET_PATTERNS:
            if pat.search(value):
                hits.append(f"{path}: matches {pat.pattern}")

    for i, rec in enumerate(doc.get("hydration", {}).get("records", [])):
        check_string(f"hydration.records[{i}].value", rec.get("value", ""))
        check_string(f"hydration.records[{i}].key", rec.get("key", ""))

    for i, art in enumerate(doc.get("artifacts", [])):
        check_string(f"artifacts[{i}].path", art.get("path", ""))

    exports = doc.get("exports") or {}
    for key in ("forum_markdown", "email_subject"):
        if key in exports and isinstance(exports[key], str):
            check_string(f"exports.{key}", exports[key])

    return hits


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: validate_bugcard.py <card.json> [--policy]", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    policy = "--policy" in sys.argv[2:]
    try:
        doc = json.loads(path.read_text())
        validate_bugcard(doc)
        if policy:
            hits = scan_export_secrets(doc)
            if hits:
                for h in hits:
                    print(f"POLICY: {h}", file=sys.stderr)
                return 1
        print("OK", path.name)
        return 0
    except ValidationError as exc:
        print(f"INVALID: {exc}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"INVALID JSON: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
