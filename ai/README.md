# AI 脚本目录

这里放与 AI 相关的辅助脚本、提示词与工作流约定 —— 也就是「AI 怎么驱动 Godot 开发」
这条主线的落地部分。

## 目录现状

```
ai/
├── scripts/
│   └── run_checks.py     # Godot 回归跑批：一条命令跑完 planet 的 12 项自测
├── prompts/
│   └── planet-iterate.md # 可复用提示词模板：改 planet 实验时必须走的验证闭环
└── examples/             # 示例输入输出（暂无）
```

## 已有的工具

### `scripts/run_checks.py`

只依赖 Python 标准库，不需要 venv 也能跑（要装进 venv 也可以，见下面约定）。

```bash
python ai/scripts/run_checks.py          # 全部检查：约 2 分钟
python ai/scripts/run_checks.py --quick  # 只跑逻辑检查：约 35 秒
python ai/scripts/run_checks.py --list   # 列出会跑哪些检查
python ai/scripts/run_checks.py --godot /path/to/Godot --project projects/planet
```

它做的事：

1. 定位 Godot 可执行文件：`--godot` > `GODOT_PATH` 环境变量 > `.mcp.json` 里的
   `GODOT_PATH` > `PATH`（和 MCP 用同一个配置，避免两边路径不一致）。
2. 依次启动游戏内的 dev 开关：4 个镜头角度的 `--dirtest`、`--selftest`、
   `--selftest-long`、6 个演化阶段的 `--shot` 截图。
3. 解析 `[dirtest] / [selftest] RESULT: PASS`，汇总成表格；有任何失败就退出码 1
   并把失败那次的原始输出打出来。

逻辑检查走 `--headless`；截图检查需要真实渲染窗口，不能 headless。

### `prompts/planet-iterate.md`

给 agent 用的提示词模板：把「必须先读代码 → 改 → 跑 `run_checks.py` → 自己看截图 →
全绿才 commit」写死在提示词里，并把已知的命令行坑列在里面。

## 约定

- 依赖装到 `.venv/`（已忽略）。建议：`python -m venv .venv && .venv/Scripts/activate`
  （`run_checks.py` 只用标准库，不装依赖也能跑）
- **密钥不要提交**：通过环境变量读取，例如 `export ANTHROPIC_API_KEY=...`
- 入口脚本放在 `ai/scripts/`，提示词放在 `ai/prompts/`
- 新实验（见 `docs/exploration.md`）先写 dev 自测开关，再写玩法；
  这样 `run_checks.py` 这类工具可以直接复用同一套「跑批 → 看结果」的流程
