# Midjourney V8.1 Prompt Skill

一个面向 Codex 的 Midjourney V8.1 提示词 Skill：将中文或英文的视觉想法编译为可直接粘贴的英文 Midjourney 提示词，并从本地 YouMind 灵感库中安全检索可迁移的构图、光线、材质与媒介语言。

## 包含内容

- V8.1 参数兼容性边界与最终提示词检查器
- 14,583 条唯一提示词、21,858 条分类记录的本地灵感库
- 主体优先的中英检索、参考图/元提示词隔离和去重规则
- 24 个检索回归、32 个参数与污染防护案例、8 个前向提示词案例
- 实测形成的数量锁与平面 UI 硬约束规则

## 安装

下载或克隆仓库后，在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装器会拒绝覆盖已有同名 Skill，重新统计本地语料，并逐文件校验 SHA-256。完成后重启 Codex。

也可以把 `midjourney-v8-1-prompt` 文件夹复制到 `%USERPROFILE%\.codex\skills\`。

## 使用

```text
$midjourney-v8-1-prompt 上海雨夜里一只橘猫，竖版电影感街拍
```

它只输出提示词，不直接替你生成图像。当前包固定面向 Midjourney V8.1；对于可能变化的参数支持，请以 Midjourney 官方文档为准。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\midjourney-v8-1-prompt\scripts\validate-artifact.ps1
```

预期结果：`VALIDATION_OK passed=94 total=94 search_skipped=False`。

## 来源与许可

本仓库的灵感语料来自 `YouMind-OpenLab/ai-image-prompts-skill`，按其 MIT 许可证重新分发。完整上游许可证见 `midjourney-v8-1-prompt/references/YOUMIND-LICENSE.txt`，来源说明见 `midjourney-v8-1-prompt/references/youmind-source.md`。

不包含任何 Midjourney 账号信息、生成结果、个人参考图或测试会话数据。
