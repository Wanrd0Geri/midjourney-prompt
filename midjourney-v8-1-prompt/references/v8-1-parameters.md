# Midjourney V8.1 compatibility boundary

Verified against official Midjourney documentation on 2026-08-15. Midjourney's current default is V8.1. This skill still emits `--v 8.1` to pin behavior if the account default changes later.

## Common controls

| Control | V8.1 guidance |
| --- | --- |
| `--v 8.1` | Always include it. Keep all parameters after the prompt text. |
| `--ar W:H` | Supported. Default is `1:1`; maximum is 14:1 in SD and 4:1 in HD. Use integer ratios. |
| `--raw` | Supported. Use for literal prompt following, realistic photography, or direct stylistic control. Use `--raw`, never `--style raw`. |
| `--s N` | Supported. Range 0–1000; default 100. Use deliberately rather than defaulting high. |
| `--c N` | Supported. Range 0–100; default 0. Higher values increase variation. |
| `--no terms` | Supported. Keep the list short and concrete. |
| `--seed N` | Supported. Add only when the user supplies or requests a seed. V8.1 seeds are highly repeatable but are not identity or style storage. |
| `--sref URL_OR_CODE` | Supported. Preserve user-provided URLs or codes exactly; never invent one. |
| `--sw N` | Supported only with `--sref`; range 0–1000, default 100. Do not use with Moodboards. |
| leading image URL + `--iw N` | Supported. V8.1 image-weight range is 0–3, default 1. Never invent a URL. |
| `--profile CODE` / `--p CODE` | Supported for personalization profiles or Moodboards. Add only when the user supplies a code. |
| `--tile` | Supported for seamless repeating patterns. |
| `--weird N` | Supported. Use only for intentional unconventional exploration. |
| `--hd` / `--sd` | V8.1 generates native 2048px HD or 1024px SD. HD costs more GPU time and limits aspect ratio to 4:1. |

## Surface-conditional controls

| Control | midjourney.com | Discord | Guidance |
| --- | --- | --- | --- |
| `--draft` | Supported | Not supported | V8.1 Draft generates a 24-image, 512px exploration batch. Use only when the user asks for rapid exploration. |
| `--fast` | Supported | Supported | Add only when the user explicitly requests Fast mode. |
| `--relax` | Supported where the plan allows | Supported where the plan allows | Add only when explicitly requested. |
| `--repeat N` / `--r N` | Supported in Fast mode | Supported in Fast mode | Use only when the user requests repeated jobs; each repeat consumes GPU time. |
| `--public` / `--stealth` | Account and plan dependent | Account and plan dependent | Preserve only when explicitly supplied. |

## Do not emit for V8.1

- `--q`: Quality is unavailable in V8.1.
- `--oref` or `--ow`: Omni Reference belongs to V7; using it switches away from V8.1.
- `--cref` or `--cw`: Character Reference and Character Weight are unavailable in V8.1.
- `::` multi-prompts or prompt weights in prompt text: compatibility stops at V6.1 and Niji 6. Weighted Style Reference URLs after `--sref` are a separate feature.
- `--turbo`: Turbo is currently unavailable in V8.1.
- `--niji`: Niji is a different model family.

Parameters must follow the prompt text, use spaces between controls, and contain no punctuation appended to their values. When a user asks whether a control is current, re-check the official documentation rather than relying on this snapshot.

## Official sources

- Version and compatibility: https://docs.midjourney.com/hc/en-us/articles/32199405667853-Version
- Parameter list: https://docs.midjourney.com/hc/en-us/articles/32859204029709-Parameter-List
- Draft and Conversational modes: https://docs.midjourney.com/hc/en-us/articles/35577175650957-Draft-Conversational-Modes
- GPU speed: https://docs.midjourney.com/hc/en-us/articles/32016412137741-GPU-Speed-Fast-Relax-Turbo
- Style Reference: https://docs.midjourney.com/hc/en-us/articles/32180011136653-Style-Reference
- Image Prompts: https://docs.midjourney.com/hc/en-us/articles/32040250122381-Image-Prompts
- Aspect ratio: https://docs.midjourney.com/hc/en-us/articles/31894244298125-Aspect-Ratio
- Multi-prompts: https://docs.midjourney.com/hc/en-us/articles/32658968492557-Multi-Prompts-Weights
