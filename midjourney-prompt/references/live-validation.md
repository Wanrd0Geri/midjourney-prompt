# Live Midjourney validation

## V8.2 migration test — 2026-08-16

Validated on midjourney.com with three matched V8.1/V8.2 task pairs: full-length fashion, clear-glass perfume product photography, and a flat finance dashboard. Each fair pair used identical prompt text, seed, aspect ratio, Raw setting, Stylize value, and explicit SD resolution. Six fair jobs produced 24 images.

An initial unpinned six-job pass was excluded from visual model scoring because the account applied HD to V8.2 while V8.1 rendered in SD. That pass established an important portability rule: when neither `--sd` nor `--hd` is present, resolution can inherit account state. Always pin the same resolution in A/B tests.

### Results

- Fashion: V8.2 was the clear winner. All four images preserved full-length framing and rendered a bolder curved shoulder line and more sculptural asymmetrical coat silhouette. V8.1 remained usable but interpreted the garment more conservatively.
- Product: V8.2 produced the more consistent commercial set, with cleaner negative space and restrained bottle/plinth compositions. V8.1 produced stronger variation and more aggressive faceting, which may still suit a dramatic legacy look.
- Flat dashboard: tie on the tested hard constraints. Both versions produced four of four edge-to-edge interfaces without device mockups. V8.2 looked slightly cleaner overall, but the difference was not large enough to treat as a general rule.

### Migration decision

Use V8.2 as the default validated model. Preserve V8.1 only when the user explicitly requests its older aesthetic or needs legacy continuity. Do not silently retain `--v 8.1` from a retrieved corpus record or an old prompt.

## Historical V8.1 prompt-architecture test — 2026-08-15

The original V8.1 package compared short generic baselines against subject-first prompts generated with the Skill.

- Eight task families, sixteen jobs, four images per job.
- Candidate prompts won all eight comparisons on instruction coverage and usable-image rate.
- Mean reviewer score: baseline 7.8/10; final candidate 9.3/10 after targeted retests.
- Strongest gains: garment-dominant fashion framing, exact poster hierarchy, product geometry, and flat information architecture.
- Residual first-pass failures: one duplicated sword and two dashboard device mockups.

The retest established the current hard-lock rule: place critical count and output-medium constraints positively before styling language, then add one concise domain-specific `--no` list only when violating the constraint would invalidate the image. This produced four of four single-sword images and four of four flat dashboard interfaces on the fixed seeds.

These results support the tested task families only. They do not imply universal compliance, and generated outputs must still be checked against hard constraints.
