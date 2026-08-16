# Live Midjourney V8.1 A/B validation

Validated on midjourney.com with Standard quality, fixed seeds, and no reference images. The baseline used short generic prompts; the candidate used this Skill's subject-first construction and parameter policy.

## First pass

- Eight task families, sixteen jobs, four images per job.
- Candidate won all eight task-family comparisons on instruction coverage and usable-image rate.
- Mean reviewer score: baseline 7.8/10; first candidate 9.15/10.
- Strongest gains: garment-dominant fashion framing, exact poster text and hierarchy, product geometry, and flat information architecture.
- Residual failures: one of four sword images duplicated the weapon; two of four dashboard images used a physical device mockup despite negative prose.

## Rule derived from failures

Critical count and output-medium constraints must be positive locks placed before styling language. When failure would invalidate the image, reinforce the lock with one concise closing count clause or a short `--no` list. Do not depend on buried words such as `single` or negative prose such as `no device mockup`.

## Targeted retest

- A positive count/canvas lock alone reduced dashboard mockups from two of four images to one of four, but did not remove the duplicate sword on the fixed seed.
- Adding a concise, domain-specific `--no` list produced four of four single-sword images and four of four flat dashboard interfaces on the same seeds.
- Replacing the two residual first-pass scores with the final retest scores raises the eight-family mean to 9.3/10.

The final two prompts were promoted into `tests/forward-prompts.json`. This is evidence for the tested task families, not a claim of universal prompt compliance; hard constraints should still be checked in generated outputs.
