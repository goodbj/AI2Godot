# Blender 共用踩坑纪律（集团级，05 维护）

> 收编自 07 动捕项目组 `AI2Blender管线踩坑.md`（67 条实测，squall01337/mixamo-llm-mocap 上游）。
> 现作为 **05 部门 Blender 共用资产**，所有用 05 工具的项目组（含 07）都遵守。
> 维护人：05_00。新增踩坑在此追加，不要散落到各项目组本地。

## 一、运行环境（铁律）

1. **本机无 GUI / 虚拟显示**：Blender 一律 `blender --background --python xxx.py` 跑批，**不依赖 MCP / GUI**。`blender_mcp` 插件在 `--background` 下 server 主动拒启动（`start()` 第一行 `if bpy.app.background: return`），纯 headless 无法 AI 直驱。
2. **Blender 5.2 已确认 slotted action API**：`action.layers/strips/channelbag`，旧 `action.fcurves` 已移除；fcurve 批量写入须实测。
3. **mcp SDK 版本钉死**：`mcp[cli]<2`。mcp SDK 2.x 会 import `mcp.server.fastmcp`（2.0 已移除），**搞坏官方 Blender MCP server**。若日后上 AI 直驱，环境必须锁 `mcp[cli]<2`。
4. **长时 apply 冻结 UI 是正常的**：300 帧约 2–4 分钟窗口无响应，别杀进程。结果写盘（`apply_result.json`），socket 掉了也不丢。

## 二、截图 / 渲染

5. **视口截图在窗口被遮挡或最小化时拍到全黑** → 静帧一律走**临时相机 + Workbench/EEVEE 渲染**，不依赖视口。
6. **陈旧静帧会烧掉轮次** → 每次重新 key 后，先删再重渲静帧，再判断任何东西。
7. **活动场景只持有 1 个 action（最后应用的那个）** → 渲染前绑定目标 action，否则预览静默显示错误动画。

## 三、导出 / 对接 Godot

8. **glTF 导出 Y-up**：`export_yup=True`（Godot 默认 Y-up），避免轴向翻转。
9. **应用修饰器/变换**：`export_apply=True`，Godot 里不炸。
10. **单位**：Blender 米 = Godot 米，`export_scale=1.0`；源文件用厘米则 `0.01`。
11. **导出后必出验证截图**（`--output-shot`），肉眼确认无穿模/无黑屏。

## 四、协议不兼容警告（重要）

12. **ahujasid/mcp-for-blender 协议 ≠ 官方 Blender Lab MCP**：前者 `{"type":"execute_code",...}` 无分隔符；后者 `{"type":"execute",...}` + `\0` 分隔符。**两者不可混用**。好消息：动捕/资产主路径都走 `blender -b --python`，不走 MCP，互不干扰。

## 五、通用纪律

13. **只信数值输出，不靠静帧判断**：肢体左右、脚着地、关节位置等，以脚本数值（`analyze_landmarks.py` 类）为准，静帧会骗人（尤其面对镜头时画面左=角色右）。
14. **一轮一个约束，已签字区域冻结**：不要回改已批准的部分（一次历史回归就是上半身批准后去"改进"脚）。
15. **QA 通过 ≠ 完成**：数值抓爆炸/弹跳/打滑/漂移，看不出错误剪影；播一遍、读静帧、问人。

> 完整 67 条原文见 07 记忆库：`E:/AI/AI_Memory/知识库/07-AI2Blender-动捕/知识库/AI2Blender管线踩坑.md`
