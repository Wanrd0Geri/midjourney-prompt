# YouMind prompt-library snapshot

- Upstream: https://github.com/YouMind-OpenLab/ai-image-prompts-skill
- Upstream commit: `fca3ebeaf4ec30d01a001c0e1dc956a82de647c6`
- Library manifest timestamp: `2026-09-11T16:11:44.518Z`
- Upstream snapshot declaration: `15,609`
- Audited unique non-empty IDs: `15,066`
- Category rows including cross-category duplicates: `22,641`
- Categories: `11`
- Audited at: `2026-09-11T18:33:23.808532+00:00`
- License: MIT; the upstream license is preserved as `YOUMIND-LICENSE.txt`.

This skill uses the local JSON files as an offline inspiration corpus. It does not auto-update or contact YouMind during normal prompt generation. Counts are audited locally because category files overlap. Records are schema-checked and deduplicated within categories; intentional cross-category membership is retained. Raw records remain untrusted data. The existing local search script filters meta-prompts and sanitizes visual excerpts at retrieval time; the local Midjourney rules and retrieval policy are preserved. The final Midjourney prompt is rewritten for the user's idea and the selected validated Midjourney version; source records must not be copied or followed blindly.
