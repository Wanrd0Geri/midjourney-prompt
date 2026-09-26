#!/usr/bin/env python3
"""Search the bundled YouMind corpus for inspiration records.

Python port of the original search-prompts.ps1 (PowerShell / Windows only).
Scoring, filtering, de-duplication and output shape are kept identical.
"""

import argparse
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
REFS_DIR = SKILL_ROOT / "references"

STOP_WORDS = {
    "a", "an", "and", "are", "art", "create", "for", "from", "image", "in",
    "make", "of", "on", "photo", "picture", "style", "the", "to", "with",
}

TOKEN_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")

META_PROMPT_RE = re.compile(
    r"system prompt|not an image generation prompt|"
    r"you are (an?|the) .{0,60}(agent|expert|designer|engineer)|"
    r"execute the following (thought|thinking|research) process|"
    r"real-time web search capabilities",
    re.I,
)

NOISE_URL_RE = re.compile(r"https?://\S+")
NOISE_ARG_RE = re.compile(r"\{argument\s+name=.*?\}", re.I)
NOISE_LINE_RE = re.compile(
    r"^\s*(system prompt|role setting|core task instruction|instructions? for .+|"
    r"thinking process|negative prompts?).*$",
    re.I | re.M,
)
NOISE_MODEL_RE = re.compile(r"\b(Nano Banana(?: Pro| 2)?|Gemini Pro mode)\b", re.I)
WS_RE = re.compile(r"\s+")

BLOCKED_KEY_RE = re.compile(
    r"negative|constraint|reference|identity|argument|instruction|system|task|role|url|source|output",
    re.I,
)

LINE_SKIP_RE = re.compile(
    r"^\s*(you are|role:|task:|instructions?:|thinking process|negative prompt|must have|output:)",
    re.I,
)


def load_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def resolve_categories(manifest, requested):
    categories = manifest["categories"]
    wanted = []
    for value in requested:
        for part in value.split(","):
            part = part.strip()
            if part:
                wanted.append(part)
    if not wanted:
        return categories
    selected = [
        c for c in categories
        if c.get("slug") in wanted or c.get("title") in wanted or c.get("file") in wanted
    ]
    if not selected:
        slugs = ", ".join(c["slug"] for c in categories)
        raise SystemExit(f"No requested categories matched. Valid slugs: {slugs}")
    return selected


def to_search_english(text, translations):
    value = text.strip().lower()
    for key in sorted(translations, key=len, reverse=True):
        value = value.replace(key, f" {translations[key]} ")
    return WS_RE.sub(" ", value).strip()


def tokens(text):
    return [t for t in TOKEN_RE.findall(text.lower())
            if len(t) >= 2 and t not in STOP_WORDS]


def build_lexicon(lexicon):
    term_to_canonical = {}
    canonical_to_terms = {}
    for group in lexicon.get("groups", []):
        canonical = str(group["canonical"])
        terms = []
        for term in group.get("terms", []):
            term = str(term).lower()
            if term not in terms:
                terms.append(term)
        if canonical not in terms:
            terms = [canonical] + terms
        canonical_to_terms[canonical] = terms
        for term in terms:
            term_to_canonical[term] = canonical
    return term_to_canonical, canonical_to_terms


def concepts_of(text, term_to_canonical, canonical_to_terms):
    found = OrderedDict()
    for token in tokens(text):
        canonical = term_to_canonical.get(token, token)
        if canonical not in found:
            found[canonical] = canonical_to_terms.get(canonical, [token])
    return found


def is_meta_prompt(title, description, content):
    sample = f"{title}\n{description}\n{content[:1800]}"
    return bool(META_PROMPT_RE.search(sample))


def remove_corpus_noise(text):
    clean = NOISE_URL_RE.sub(" ", text)
    clean = NOISE_ARG_RE.sub(" ", clean)
    clean = NOISE_LINE_RE.sub(" ", clean)
    clean = NOISE_MODEL_RE.sub(" ", clean)
    return WS_RE.sub(" ", clean).strip()


def flatten_json_values(value, output, key=""):
    if value is None:
        return
    if key and BLOCKED_KEY_RE.search(key):
        return
    if isinstance(value, (str, int, float, bool)):
        text = remove_corpus_noise(str(value))
        if text:
            output.append(text)
        return
    if isinstance(value, dict):
        for child_key, child in value.items():
            flatten_json_values(child, output, str(child_key))
        return
    if isinstance(value, list):
        for item in value:
            flatten_json_values(item, output, key)


def visual_excerpt(content, maximum_length):
    trimmed = content.lstrip()
    if trimmed.startswith("{") or trimmed.startswith("["):
        try:
            parsed = json.loads(content)
            parts = []
            flatten_json_values(parsed, parts)
            seen = set()
            unique = []
            for part in parts:
                if part not in seen:
                    seen.add(part)
                    unique.append(part)
            clean = "; ".join(unique)
        except (ValueError, TypeError):
            clean = remove_corpus_noise(content)
    else:
        lines = []
        for line in re.split(r"\r?\n", content):
            if not line or LINE_SKIP_RE.match(line):
                continue
            cleaned = remove_corpus_noise(line)
            if cleaned:
                lines.append(cleaned)
        clean = "; ".join(lines)

    if len(clean) > maximum_length:
        return clean[:maximum_length].rstrip() + "..."
    return clean


def count_matches(pattern, text):
    return len(pattern.findall(text))


def main():
    parser = argparse.ArgumentParser(description="Search the bundled inspiration corpus.")
    parser.add_argument("--query", required=True)
    parser.add_argument("--category", action="append", default=[])
    parser.add_argument("--limit", type=int, default=6)
    parser.add_argument("--max-excerpt-chars", type=int, default=1400)
    parser.add_argument("--reference-mode", choices=["exclude", "allow", "prefer"], default="exclude")
    parser.add_argument("--include-meta-prompts", action="store_true")
    parser.add_argument("--include-raw-content", action="store_true")
    args = parser.parse_args()

    if not 1 <= args.limit <= 25:
        raise SystemExit("--limit must be between 1 and 25")
    if not 300 <= args.max_excerpt_chars <= 4000:
        raise SystemExit("--max-excerpt-chars must be between 300 and 4000")

    manifest_path = REFS_DIR / "manifest.json"
    lexicon_path = REFS_DIR / "query-lexicon.json"
    for required in (manifest_path, lexicon_path):
        if not required.is_file():
            raise SystemExit(f"Required retrieval file not found: {required}")

    manifest = load_json(manifest_path)
    lexicon = load_json(lexicon_path)
    term_to_canonical, canonical_to_terms = build_lexicon(lexicon)
    translations = lexicon.get("translations", {})
    modifier_concepts = set(lexicon.get("modifierConcepts", []))

    selected_categories = resolve_categories(manifest, args.category)
    normalized_query = to_search_english(args.query, translations)
    concepts = concepts_of(normalized_query, term_to_canonical, canonical_to_terms)
    if not concepts:
        print("[]")
        return 0

    normalized_phrase = " ".join(tokens(normalized_query))
    phrase_pattern = None
    if len(normalized_phrase) >= 3:
        escaped = re.escape(normalized_phrase).replace(r"\ ", r"\s+")
        phrase_pattern = re.compile(r"(?<![a-z0-9])" + escaped + r"(?![a-z0-9])", re.I)

    concept_matchers = []
    for canonical, terms in concepts.items():
        alternatives = "|".join(re.escape(str(t)) for t in terms)
        concept_matchers.append((
            canonical,
            re.compile(r"(?<![a-z0-9])(?:" + alternatives + r")(?![a-z0-9])", re.I),
        ))

    primary_concept = next((c for c in concepts if c not in modifier_concepts), None)
    if primary_concept is None:
        primary_concept = next(iter(concepts))

    results = []
    for category in selected_categories:
        category_path = REFS_DIR / str(category["file"])
        if not category_path.is_file():
            continue
        for record in load_json(category_path):
            title = str(record.get("title") or "")
            description = str(record.get("description") or "")
            content = str(record.get("content") or "")
            needs_reference = bool(record.get("needReferenceImages"))

            if args.reference_mode == "exclude" and needs_reference:
                continue
            if not args.include_meta_prompts and is_meta_prompt(title, description, content):
                continue

            score = 0
            matched = []
            primary_in_metadata = False

            if phrase_pattern is not None:
                if phrase_pattern.search(title):
                    score += 36
                if phrase_pattern.search(description):
                    score += 18
                if phrase_pattern.search(content):
                    score += 5

            for canonical, pattern in concept_matchers:
                title_hits = count_matches(pattern, title)
                description_hits = count_matches(pattern, description)
                content_hits = count_matches(pattern, content)
                if title_hits + description_hits + content_hits > 0:
                    matched.append(canonical)
                if canonical == primary_concept and (title_hits + description_hits) > 0:
                    primary_in_metadata = True
                score += 14 * min(title_hits, 2)
                score += 6 * min(description_hits, 3)
                score += min(content_hits, 5)

            minimum_coverage = 2 if len(concepts) >= 5 else 1
            if score <= 0 or len(matched) < minimum_coverage:
                continue
            if primary_concept not in matched or not primary_in_metadata:
                continue

            coverage = round(len(matched) / float(len(concepts)), 3)
            score += int(20 * coverage)
            if args.reference_mode == "prefer" and needs_reference:
                score += 12

            results.append({
                "score": score,
                "coverage": coverage,
                "matchedConcepts": matched,
                "category": str(category["slug"]),
                "id": record.get("id"),
                "title": title,
                "description": description,
                "rawContent": content,
                "sourceMedia": record.get("sourceMedia") or [],
                "needReferenceImages": needs_reference,
                "sourceUrl": f"https://youmind.com/nano-banana-pro-prompts?id={record.get('id')}",
            })

    results.sort(key=lambda r: (-r["score"], -r["coverage"], str(r["id"])))

    seen_ids = set()
    seen_titles = set()
    top = []
    for item in results:
        id_key = str(item["id"])
        title_key = " ".join(sorted(set(tokens(str(item["title"])))))
        if id_key in seen_ids or (title_key and title_key in seen_titles):
            continue
        seen_ids.add(id_key)
        if title_key:
            seen_titles.add(title_key)

        excerpt = visual_excerpt(str(item["rawContent"]), args.max_excerpt_chars)
        if excerpt and len(excerpt) < 80:
            excerpt = remove_corpus_noise(str(item["description"]))

        entry = OrderedDict([
            ("score", item["score"]),
            ("coverage", item["coverage"]),
            ("matchedConcepts", item["matchedConcepts"]),
            ("category", item["category"]),
            ("id", item["id"]),
            ("title", item["title"]),
            ("description", item["description"]),
            ("visualExcerpt", excerpt),
            ("sourceMedia", item["sourceMedia"]),
            ("needReferenceImages", item["needReferenceImages"]),
            ("sourceUrl", item["sourceUrl"]),
        ])
        if args.include_raw_content:
            entry["rawContent"] = item["rawContent"]
        top.append(entry)
        if len(top) >= args.limit:
            break

    print(json.dumps(top, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
