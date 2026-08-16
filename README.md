# Midjourney Prompt Skill

一个面向 Codex 的版本感知型 Midjourney 提示词 Skill：将中文或英文的视觉想法编译为可直接粘贴的英文 Midjourney 提示词，并从本地 YouMind 灵感库中安全检索可迁移的构图、光线、材质与媒介语言。当前默认并固定输出 V8.2，用户明确要求时保留 V8.1 兼容模式。

## 包含内容

- V8.2 默认参数边界、V8.1 兼容模式与版本感知检查器
- 14,583 条唯一提示词、21,858 条分类记录的本地灵感库
- 主体优先的中英检索、参考图/元提示词隔离和去重规则
- 24 个检索回归、36 个参数与污染防护案例、8 个前向提示词案例
- 实测形成的数量锁与平面 UI 硬约束规则

## 安装

下载或克隆仓库后，在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装器会拒绝覆盖已有同名 Skill，重新统计本地语料，并逐文件校验 SHA-256。完成后重启 Codex。

也可以把 `midjourney-prompt` 文件夹复制到 `%USERPROFILE%\.codex\skills\`。

## 使用

```text
$midjourney-prompt 上海雨夜里一只橘猫，竖版电影感街拍
```

它只输出提示词，不直接替你生成图像。默认固定 `--v 8.2`，避免账号默认版本变化导致同一提示词悄悄换模型；只有用户明确要求时才使用 `--v 8.1`。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\midjourney-prompt\scripts\validate-artifact.ps1
```

预期结果：`VALIDATION_OK passed=98 total=98 search_skipped=False`。

## 来源与许可

本仓库的灵感语料来自 `YouMind-OpenLab/ai-image-prompts-skill`，按其 MIT 许可证重新分发。完整上游许可证见 `midjourney-prompt/references/YOUMIND-LICENSE.txt`，来源说明见 `midjourney-prompt/references/youmind-source.md`。

不包含任何 Midjourney 账号信息、生成结果、个人参考图或测试会话数据。
