# AI2Godot

> 一个专门用于探索 **AI × Godot** 结合开发游戏的项目。

本仓库用来做实验性探索：如何用 AI（大语言模型、智能体、程序化生成等）辅助或驱动基于 Godot 引擎的游戏开发。目标是沉淀可复用的思路、脚本和最小可运行示例，而不是一上来就做完整游戏。

## 项目结构

```
AI2Godot/
├── projects/       # 可运行的 Godot 工程
│   └── planet/     # 星球演化游戏（大鱼吃小鱼）
├── godot/          # 早期实验场景（保留）
├── ai/             # AI 相关脚本与工具（Python 辅助脚本、提示词、智能体配置）
├── docs/           # 调研笔记、方案对比、实验记录
├── .mcp.json       # Godot MCP 桥配置（AI 直接操作 Godot）
├── .github/        # CI / 模板（可选）
└── README.md
```

## 已接入的基础设施

- **Godot MCP 桥**：Claude 通过 MCP 直接操作 Godot 编辑器与工程（建场景、跑项目、抓报错）。
  配置见 `.mcp.json`，接入过程与踩坑见 [docs/ai-godot-mcp.md](docs/ai-godot-mcp.md)。
- **回归跑批 `ai/scripts/run_checks.py`**：一条命令跑完 planet 的全部自测
  （4 个镜头角度的操作映射检查 + 18s 玩法自测 + 60s 平衡测试 + 6 个演化阶段截图），
  输出 PASS/FAIL 汇总表；截图落在 `build/shots/`（已忽略），AI 直接看图判断外观。
  零依赖，只用 Python 标准库，Godot 路径从 `GODOT_PATH` 或 `.mcp.json` 自动定位。

  ```bash
  python ai/scripts/run_checks.py          # 全套，约 2 分钟
  python ai/scripts/run_checks.py --quick  # 只跑逻辑检查，约 35 秒
  ```

## 已完成的实验

- **[planet](projects/planet/)** — 太空版大鱼吃小鱼。从陨石靠吸收碎石成长为
  行星、恒星、白矮星，最终坍缩成黑洞。全程序化着色器，无外部美术资源。
  环绕相机（鼠标/右半屏拖动转视角，移动方向跟随镜头），支持桌面与手机。
  带自测脚本（`--selftest` / `--selftest-long` / `--dirtest` / `--stage=N --shot`），
  AI 可自行验证玩法、平衡与画面。

## 探索方向

- [x] **代码辅助**：AI 生成 / 修改 GDScript，并自动验证能不能跑。
      已在 planet 实验里跑通闭环（dev 自测开关 + `ai/scripts/run_checks.py` + 截图回看），
      可复用的提示词见 [`ai/prompts/planet-iterate.md`](ai/prompts/planet-iterate.md)。
- [ ] **关卡 / 内容程序化生成**：让 LLM 产出关卡描述或 NPC 对话，Godot 解析后生成场景。
- [ ] **AI 驱动 NPC**：用 LLM 作为 NPC 的"大脑"，实时对话与决策。
- [ ] **智能体编排**：多个 AI 角色在 Godot 里协作或对抗。
- [ ] **资源生成**：AI 生成美术、音频描述并落进 Godot。

进度与结论记录在 [docs/exploration.md](docs/exploration.md)。

## 工作流

1. 在 `docs/` 里记录某个方向的调研与可行方案。
2. 在 `ai/` 里放对应的 AI 脚本 / 提示词（注意：密钥不要提交，见 `.gitignore`）。
3. 在 `godot/` 里建最小可运行示例来验证。
4. 跑通后用 README 或 docs 记录结论。

## 环境约定

- Godot 4.x（GDScript 为主，如需 C# 再引入 Mono）。
- AI 脚本用 Python（建议 `.venv` 隔离依赖，已加入 `.gitignore`）。
- 所有 API Key 通过环境变量传入，不要写进代码或提交。

---
*这是一个探索性仓库，欢迎随时调整结构与方向。*
