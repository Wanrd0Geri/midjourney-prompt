#!/usr/bin/env python3
"""Validate a finished Midjourney prompt against the target version's parameter rules.

Python port of the original lint-prompt.ps1 (PowerShell / Windows only).
Checks, codes and exit status are kept identical.
"""

import argparse
import json
import re
import sys
from collections import Counter, OrderedDict

ALLOWED = {
    "v", "version", "ar", "aspect", "raw", "s", "stylize", "c", "chaos", "no",
    "seed", "sref", "sw", "iw", "tile", "weird", "w", "profile", "p", "hd", "sd",
    "draft", "fast", "relax", "repeat", "r", "public", "stealth",
}
FORBIDDEN = {"q", "quality", "oref", "ow", "cref", "cw", "turbo", "niji"}

PARAM_RE = re.compile(r"(?<!\S)--(?P<name>[a-z]+)(?:\s+(?!-{2})(?P<value>\S+))?", re.I)
VERSION_RE = re.compile(r"(?<!\S)--(?:v|version)\s+(?P<value>\S+)", re.I)
ASPECT_RE = re.compile(r"(?<!\S)--(?:ar|aspect)\s+(?P<w>[^:\s]+):(?P<h>\S+)", re.I)


def unique(items):
    seen = set()
    out = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def lint(prompt, surface, target_version, strict):
    errors = []
    warnings = []

    matches = list(PARAM_RE.finditer(prompt))
    names = [m.group("name").lower() for m in matches]

    for name in names:
        if name in FORBIDDEN:
            errors.append(f"unsupported_parameter:{name}")
        elif name not in ALLOWED:
            warnings.append(f"unknown_parameter:{name}")

    version_match = VERSION_RE.search(prompt)
    if not version_match:
        errors.append(f"missing_version:--v {target_version}")
    elif version_match.group("value") != target_version:
        errors.append(f"wrong_version:{version_match.group('value')}")

    if "draft" in names and surface == "discord":
        errors.append(f"draft_is_web_only_for_v{target_version}")

    if "hd" in names and "sd" in names:
        errors.append("conflicting_resolution:hd_and_sd")
    elif "hd" not in names and "sd" not in names:
        warnings.append("resolution_inherits_account_setting")

    if "sw" in names and "sref" not in names:
        errors.append("sw_requires_sref")

    if "iw" in names and not re.search(r"^\s*https?://\S+", prompt):
        errors.append("iw_requires_leading_image_url")

    if ("repeat" in names or "r" in names) and "fast" not in names:
        warnings.append(f"repeat_requires_fast_mode_in_v{target_version}")

    aspect_match = ASPECT_RE.search(prompt)
    if aspect_match:
        try:
            width = int(aspect_match.group("w"))
            height = int(aspect_match.group("h"))
            if width <= 0 or height <= 0:
                raise ValueError
        except ValueError:
            errors.append("aspect_ratio_must_use_positive_integers")
        else:
            ratio = max(width / float(height), height / float(width))
            maximum = 4.0 if "hd" in names else 14.0
            if ratio > maximum:
                errors.append(f"aspect_ratio_exceeds_{maximum}:1")

    first_parameter_index = prompt.find("--")
    if first_parameter_index > 0:
        prompt_text = prompt[:first_parameter_index]
        if "::" in prompt_text:
            errors.append(f"multiprompt_weights_unavailable_in_v{target_version}")

    if prompt.lstrip().startswith("{") or re.search(
        r'"(?:type|positive|negative_prompt)"\s*:', prompt, re.I
    ):
        errors.append("raw_json_leakage")

    if re.search(
        r"\{argument\s+name=|\bNano Banana(?: Pro| 2)?\b|\bGemini Pro mode\b", prompt, re.I
    ):
        errors.append("source_template_leakage")

    if re.search(r"^\s*(you are|role:|task:|system prompt)", prompt, re.I):
        errors.append("meta_instruction_leakage")

    if re.search(r"\b(masterpiece|best quality|8k|16k|award-winning)\b", prompt, re.I):
        warnings.append("quality_filler_detected")

    if re.search(r"\bnegative prompt\s*:", prompt, re.I):
        warnings.append("rewrite_negative_prompt_as_positive_constraints")

    for name, count in Counter(names).items():
        if count > 1 and name not in ("sref", "no"):
            errors.append(f"duplicate_parameter:{name}")

    for match in matches:
        value = match.group("value") or ""
        if re.search(r"[,;.]$", value):
            errors.append(f"parameter_value_has_punctuation:{match.group('name')}")

    if strict:
        for warning in list(warnings):
            errors.append(f"strict:{warning}")

    return OrderedDict([
        ("valid", len(errors) == 0),
        ("surface", surface),
        ("targetVersion", target_version),
        ("errors", unique(errors)),
        ("warnings", unique(warnings)),
        ("parameters", names),
    ])


def main():
    parser = argparse.ArgumentParser(description="Lint a finished Midjourney prompt.")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--surface", choices=["web", "discord"], default="web")
    parser.add_argument("--target-version", choices=["8.2", "8.1"], default="8.2")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if not args.prompt.strip():
        raise SystemExit("--prompt must not be empty")

    result = lint(args.prompt, args.surface, args.target_version, args.strict)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
