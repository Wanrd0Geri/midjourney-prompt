#!/usr/bin/env python3
"""Self-check for the midjourney-prompt skill: files, corpus integrity, lint and search cases.

Python port of the original validate-artifact.ps1 (PowerShell / Windows only).
Run after editing the skill or refreshing the corpus:

    python3 scripts/validate_artifact.py [--skip-search-tests]
"""

import argparse
import json
import re
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
REFS_DIR = SKILL_ROOT / "references"
TESTS_DIR = SKILL_ROOT / "tests"
SCRIPTS_DIR = SKILL_ROOT / "scripts"

sys.path.insert(0, str(SCRIPTS_DIR))
import lint_prompt  # noqa: E402
import search_prompts  # noqa: E402

REQUIRED_FILES = [
    "SKILL.md",
    "references/manifest.json",
    "references/version-parameters.md",
    "references/retrieval-policy.md",
    "references/query-lexicon.json",
    "references/YOUMIND-LICENSE.txt",
    "scripts/search_prompts.py",
    "scripts/lint_prompt.py",
    "tests/search-cases.json",
    "tests/lint-cases.json",
    "tests/forward-prompts.json",
]

FRONTMATTER_RE = re.compile(
    r"\A---\r?\nname: midjourney-prompt\r?\ndescription: [^\r\n]+\r?\n---"
)


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


class Report:
    def __init__(self):
        self.passed = 0
        self.failures = []

    def ok(self):
        self.passed += 1

    def fail(self, message):
        self.failures.append(message)

    def check(self, condition, message):
        if condition:
            self.ok()
        else:
            self.fail(message)


def check_files(report):
    for relative in REQUIRED_FILES:
        report.check((SKILL_ROOT / relative).is_file(), f"missing_file:{relative}")


def check_skill_md(report):
    try:
        text = (SKILL_ROOT / "SKILL.md").read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        report.fail(f"skill_utf8_or_read_error:{exc}")
        return
    report.check(bool(FRONTMATTER_RE.match(text)), "invalid_skill_frontmatter")
    report.check(len(text.split("\n")) < 500, "skill_md_exceeds_500_lines")


def check_corpus(report):
    try:
        manifest = load_json(REFS_DIR / "manifest.json")
        ids = set()
        rows = 0
        bad = 0
        unique_reference = 0
        unique_json = 0
        seen = set()

        for category in manifest["categories"]:
            records = load_json(REFS_DIR / str(category["file"]))
            report.check(
                len(records) == int(category["count"]),
                f"category_count_mismatch:{category['slug']}:{len(records)}:{category['count']}",
            )
            for record in records:
                rows += 1
                record_id = str(record.get("id") or "")
                if (not record_id.strip()
                        or not str(record.get("title") or "").strip()
                        or not str(record.get("content") or "").strip()):
                    bad += 1
                ids.add(record_id)
                if record_id not in seen:
                    seen.add(record_id)
                    if record.get("needReferenceImages"):
                        unique_reference += 1
                    trimmed = str(record.get("content") or "").lstrip()
                    if trimmed.startswith("{") or trimmed.startswith("["):
                        unique_json += 1

        report.check(bad == 0, f"bad_required_records:{bad}")
        report.check(rows == int(manifest["totalRows"]), f"row_count:{rows}:{manifest['totalRows']}")
        report.check(
            len(ids) == int(manifest["totalPrompts"]),
            f"unique_count:{len(ids)}:{manifest['totalPrompts']}",
        )
        report.check(
            unique_reference == int(manifest["quality"]["uniqueReferenceRequired"]),
            f"reference_quality_count:{unique_reference}",
        )
        report.check(
            unique_json == int(manifest["quality"]["uniqueJsonStructured"]),
            f"json_quality_count:{unique_json}",
        )
    except (OSError, ValueError, KeyError) as exc:
        report.fail(f"manifest_or_corpus_error:{exc}")


def check_lint_cases(report):
    for case in load_json(TESTS_DIR / "lint-cases.json"):
        actual = lint_prompt.lint(
            case["prompt"],
            case.get("surface", "web"),
            case.get("targetVersion", "8.2"),
            bool(case.get("strict")),
        )
        if bool(actual["valid"]) == bool(case["valid"]):
            report.ok()
        else:
            report.fail(
                f"lint_case:{case['id']}:expected={case['valid']}:"
                f"actual={actual['valid']}:{','.join(actual['errors'])}"
            )


def check_forward_prompts(report):
    for case in load_json(TESTS_DIR / "forward-prompts.json"):
        if re.search(r"(?<!\S)--no(?:\s|$)", case["prompt"]):
            report.fail(f"forward_prompt_uses_default_no:{case['id']}")
        else:
            report.ok()
        actual = lint_prompt.lint(
            case["prompt"],
            case.get("surface", "web"),
            case.get("targetVersion", "8.2"),
            False,
        )
        if actual["valid"]:
            report.ok()
        else:
            report.fail(f"forward_prompt:{case['id']}:{','.join(actual['errors'])}")


def run_search(query, category, limit):
    argv = sys.argv
    sys.argv = [
        "search_prompts.py", "--query", query, "--category", category, "--limit", str(limit),
    ]
    import contextlib
    import io
    buffer = io.StringIO()
    try:
        with contextlib.redirect_stdout(buffer):
            search_prompts.main()
    finally:
        sys.argv = argv
    return json.loads(buffer.getvalue() or "[]")


def check_search_cases(report):
    for case in load_json(TESTS_DIR / "search-cases.json"):
        try:
            records = run_search(case["query"], case["category"], 3)
        except Exception as exc:  # noqa: BLE001 - reported as a failure row
            report.fail(f"search_case_error:{case['id']}:{exc}")
            continue
        if not records:
            report.fail(f"search_case_empty:{case['id']}")
            continue
        metadata = "\n".join(f"{r['title']} {r['description']}" for r in records)
        if re.search(case["expected"], metadata):
            report.ok()
        else:
            report.fail(f"search_case_irrelevant:{case['id']}:{records[0]['title']}")


def main():
    parser = argparse.ArgumentParser(description="Validate the midjourney-prompt skill.")
    parser.add_argument("--skip-search-tests", action="store_true")
    args = parser.parse_args()

    report = Report()
    check_files(report)
    check_skill_md(report)
    check_corpus(report)
    check_lint_cases(report)
    check_forward_prompts(report)
    if not args.skip_search_tests:
        check_search_cases(report)

    total = report.passed + len(report.failures)
    if report.failures:
        print(f"VALIDATION_FAILED passed={report.passed} total={total} failures={len(report.failures)}")
        for failure in report.failures:
            print(f"ERROR {failure}")
        return 1

    print(f"VALIDATION_OK passed={report.passed} total={total} search_skipped={args.skip_search_tests}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
