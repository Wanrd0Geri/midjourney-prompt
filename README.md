# midjourney-prompt

Midjourney 提示词 skill（默认 V8.2）：本地检索 YouMind 灵感库、参数 linter、整包自检。Claude Code 与 Codex 共用同一份文件。

- 安装、同步与改动规则见 [Wanrd0Geri/skills-setup](https://github.com/Wanrd0Geri/skills-setup)。不要直接 clone 进 `~/.claude/skills` 或 `~/.codex/skills`。
- 仓库根目录就是 skill 本体。2026-09-26 之前的旧版（Windows 安装包结构：`midjourney-prompt/midjourney-prompt/` 加 `install.ps1`、`开始安装.bat`）保留在 tag `pre-shared-20260926`。
- 脚本全部是 Python 3，不需要第三方包；原来的 PowerShell 脚本已移植。自检：`python3 -X utf8 scripts/validate_artifact.py`，应输出 `VALIDATION_OK passed=105 total=105`。
- 灵感库来自 YouMind，许可见 `references/YOUMIND-LICENSE.txt`；仓库 [LICENSE](LICENSE) 沿用原仓库。
