# AI 脚本目录

这里放与 AI 相关的辅助脚本（Python 为主）：

- 调用 LLM API 的封装
- 提示词（prompts）与模板
- 把 AI 输出转换为 Godot 可用数据的工具

## 约定

- 依赖装到 `.venv/`（已忽略）。建议：`python -m venv .venv && .venv/Scripts/activate`
- **密钥不要提交**：通过环境变量读取，例如 `export ANTHROPIC_API_KEY=...`
- 入口脚本建议放在 `ai/scripts/`，提示词放在 `ai/prompts/`

可用子目录（按需创建）：

```
ai/
├── scripts/     # 可运行的 Python 脚本
├── prompts/     # 提示词模板
└── examples/    # 示例输入输出
```
