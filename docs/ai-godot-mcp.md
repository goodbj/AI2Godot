# AI 连接 Godot：MCP 桥接入记录

记录把 Claude 接到 Godot 编辑器/工程的完整过程、能力边界和踩坑。

## 结论速览

AI 通过 **MCP（Model Context Protocol）** 操作 Godot，链路是：

```
Claude Code  <--stdio-->  godot-mcp (Node.js)  <--CLI/子进程-->  Godot 可执行文件
```

配置写在仓库根的 `.mcp.json`（项目级，随仓库走、可复现），不需要全局安装。

## 配置

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "@coding-solo/godot-mcp"],
      "env": {
        "GODOT_PATH": "D:/UE/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe",
        "DEBUG": "true"
      }
    }
  }
}
```

- `GODOT_PATH` 必须指向**真正的 exe**。本机下载包解压后是 `Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`（同名文件夹套同名 exe），容易指错。
- 路径用**正斜杠**，Windows 反斜杠在 JSON/MCP 配置里会出问题。
- `-y` 让 npx 不会卡在安装确认提示上（stdio 场景下没人能按 y）。

## 可用能力（实测）

| 工具 | 说明 | 实测结果 |
|---|---|---|
| `get_godot_version` | 引擎版本 | ✅ 4.7.2.stable.official.ed1daf0bf |
| `get_project_info` | 工程结构统计 | ✅ 正确识别 scenes/scripts/assets |
| `add_node` | 往场景加节点 | ⚠️ 能用，但有坑（见下） |
| `create_scene` / `save_scene` | 建/存场景 | ✅ |
| `run_project` | 启动项目 | ✅ |
| `get_debug_output` | 抓 stdout / 报错 | ✅ 闭环关键 |
| `stop_project` | 停止 | ✅ |

## 关键踩坑

### 1. `add_node` 静默丢失 Vector2 属性和 scene uid

给 `Label` 设置 `position: [100, 100]` 时，MCP 日志显示 `Setting property: position = [100.0, 100.0]`，
但保存出来的 `.tscn` 里**没有这一行**。同时场景头的 `uid="uid://..."` 也被丢掉了。

**对策**：复杂场景不要依赖 `add_node`，让 AI 直接写 `.tscn` 文本更可靠。
文本格式可控、可 diff、不会有静默丢失。

### 2. `class_name` 与 preload 的加载顺序冲突

用 `class_name World` 并在 `main.gd` 里 `preload("res://scripts/world.gd")` 时，
运行报 `Parser Error: Could not find type "World" in the current scope`。

**对策**：去掉跨文件的 `class_name` 类型引用，改用 `preload(...)` 拿脚本，
变量声明用基类（`Node3D` / `RigidBody3D`）或干脆不标注类型。

### 3. `project.godot` 不设主场景时 run 是空窗口

`run_project` 能"成功启动"，但没有任何输出，因为没有 `run/main_scene`。

**对策**：显式写 `run/main_scene="res://scenes/main.tscn"`。

### 4. PowerShell 里 `claude mcp add` 参数被吞

```
claude mcp add godot ... -- npx @coding-solo/godot-mcp
→ error: missing required argument 'commandOrUrl'
```

PowerShell 把裸 `@coding-solo/...` 当成 splatting 运算符；加引号也没解决；
`--%` 停解析符报 `unknown option '--%'`（`claude` 是包装脚本，`--%` 被原样传给 CLI）。

**对策**：**不要用 CLI 加 MCP**，直接写 `.mcp.json`。省事且可提交。

## 验证闭环

用 `projects/planet` 实测通过：

1. AI 调 `add_node` 改场景 → 文件落盘
2. `run_project` 启动 → `get_debug_output` 拿到 `planet: scene ready` 等输出
3. 画面确认（见下）

## 截图 / 自测工具

工程里留了两个开发期辅助脚本（只在带命令行参数时激活，正常运行无影响）：

- `scripts/dev_screenshot.gd` — `-- --shot --shot-path=xxx.png` 在指定时间截取 viewport 后退出
- `scripts/selftest.gd` — `-- --selftest` 自动朝最近可吃碎片移动 18 秒，报告质量增长与阶段变化

这两个脚本让 AI 能**自己看到画面、自己验证玩法**，是闭环里最有价值的部分：

```bash
# 截图（直接调 Godot，不经过 MCP）
Godot_v4.7.2-stable_win64_console.exe --path . -- --shot --shot-path=E:/out.png

# 玩法自测
Godot_v4.7.2-stable_win64_console.exe --path . -- --selftest
```

`--stage=N` 可以把玩家直接跳到第 N 个演化阶段，方便逐个检查视觉。
