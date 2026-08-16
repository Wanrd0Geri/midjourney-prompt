# Midjourney version compatibility boundary

Verified on 2026-08-16. Midjourney announced V8.2 on 2026-07-24, and the signed-in web creation interface currently selects 8.2. The older documentation pages still describe V8.1, so treat the official V8.2 announcement and the live interface as the current authority until the detailed compatibility chart catches up.

Pin `--v 8.2` by default. Use `--v 8.1` only when the user explicitly asks for the legacy model. Pinning prevents a future account-default change from silently altering an already validated prompt.

## Common controls

| Control | V8.2 guidance |
| --- | --- |
| `--v 8.2` | Include by default. Keep all parameters after the prompt text. |
| `--ar W:H` | Supported. Default is `1:1`; use positive integer ratios. Current SD/HD limits retain the tested V8.1 boundary of 14:1 and 4:1 respectively until official V8.2 documentation states otherwise. |
| `--raw` | Supported in the live V8.2 interface. Use for literal prompt following, realistic photography, or direct stylistic control. Use `--raw`, never `--style raw`. |
| `--s N` | Supported in the live V8.2 interface. Retain the documented 0–1000 range and default 100 until superseded. |
| `--c N` | Supported as Variety in the live V8.2 interface. Retain the documented 0–100 range and default 0 until superseded. |
| `--no terms` | Supported. Keep the list short and concrete. |
| `--seed N` | Supported. Add only when the user supplies or requests a seed; do not treat seeds as identity or style storage. |
| `--sref URL_OR_CODE` | Supported. Preserve user-provided URLs or codes exactly; never invent one. |
| `--sw N` | Use only with `--sref`; retain the documented 0–1000 range and default 100. Do not use with Moodboards. |
| leading image URL + `--iw N` | Supported. Retain the documented image-weight range 0–3 and default 1. Never invent a URL. |
| `--profile CODE` / `--p CODE` | Supported for personalization profiles or Moodboards. V8.2 specifically improves personalization. Add only when the user supplies a code. |
| `--tile` | Supported for seamless repeating patterns. |
| `--weird N` | Supported as Weirdness in the live V8.2 interface. Use only for intentional unconventional exploration. |
| `--hd` / `--sd` | Supported in the live V8.2 interface. HD produces the higher-resolution path and consumes more GPU time. |

## Surface-conditional controls

| Control | midjourney.com | Discord | Guidance |
| --- | --- | --- | --- |
| `--draft` | Supported in the live V8.2 interface | Treat as unsupported until officially verified | Use only when the user asks for rapid exploration. |
| `--fast` | Supported | Supported | Add only when the user explicitly requests Fast mode. |
| `--relax` | Supported where the plan allows | Supported where the plan allows | Add only when explicitly requested. |
| `--repeat N` / `--r N` | Supported in Fast mode | Supported in Fast mode | Use only when the user requests repeated jobs; each repeat consumes GPU time. |
| `--public` / `--stealth` | Account and plan dependent | Account and plan dependent | Preserve only when explicitly supplied. |

## Do not emit by default

- `--q`: current official parameter pages still mark Quality unavailable for the V8 model family.
- `--oref` or `--ow`: Omni Reference is documented for V7 and may switch model families.
- `--cref` or `--cw`: Character Reference is not documented for V8.1/V8.2.
- `::` multi-prompts or prompt weights in prompt text: current compatibility documentation stops at V6.1 and Niji 6. Weighted Style Reference URLs after `--sref` are a separate feature.
- `--turbo`: the live V8.2 web interface exposes Fast and Relax, not Turbo.
- `--niji`: Niji is a different model family.

Parameters must follow the prompt text, use spaces between controls, and contain no punctuation appended to their values. When a user asks whether a control is current, re-check official sources and prefer a live non-destructive interface check when the detailed documentation has not caught up.

## Legacy V8.1 mode

When the user explicitly requests V8.1, append `--v 8.1` and lint with `-TargetVersion 8.1`. The same conservative parameter boundary above applies. Do not select V8.1 merely because retrieved corpus text or an existing prompt contains that suffix; confirm that the user actually wants the older model.

## Official sources

- V8.2 announcement: https://updates.midjourney.com/version-8-2/
- Version and compatibility: https://docs.midjourney.com/hc/en-us/articles/32199405667853-Version
- Parameter list: https://docs.midjourney.com/hc/en-us/articles/32859204029709-Parameter-List
- Creation settings: https://docs.midjourney.com/hc/en-us/articles/32868982949517-Creation-Settings-in-Discord
- Draft and Conversational modes: https://docs.midjourney.com/hc/en-us/articles/35577175650957-Draft-Conversational-Modes
- GPU speed: https://docs.midjourney.com/hc/en-us/articles/32016412137741-GPU-Speed-Fast-Relax-Turbo
- Style Reference: https://docs.midjourney.com/hc/en-us/articles/32180011136653-Style-Reference
- Image Prompts: https://docs.midjourney.com/hc/en-us/articles/32040250122381-Image-Prompts
- Aspect ratio: https://docs.midjourney.com/hc/en-us/articles/31894244298125-Aspect-Ratio
- Multi-prompts: https://docs.midjourney.com/hc/en-us/articles/32658968492557-Multi-Prompts-Weights
