# 05 部门 Blender 共用资产库

> 维护人：05_00（工具正主）。Blender / Godot / UE 三类创作工具归 05 管、05 维护。
> 本库是**集团共用资产**：07 动捕项目组等兄弟项目组直接使用，不走"跨部门划界"。

## 关系定性（老泡儿 2026-11-11 拍板）

- **05 = 工具正主 + 维护方**：软件安装/版本/MCP 桥/脚本范式/踩坑库都由 05 维护。
- **07 = 独立项目组**：业务上做动捕，但**工具层用 05 的 Blender 生产线**，是"东道主供工具、项目组共用"。
- 集团职责速查里 07 仍标"动捕"业务，但**工具归属与业务归属分离**——不冲突。

## 目录

```
blender_assets/
├── scripts/
│   └── export_gltf.py       05 专用：Blender→glTF(gb) 导出 + 验证截图（headless）
└── docs/
    └── blender_shared_pitfalls.md   共用踩坑纪律（收编 07 的 67 条，提炼为通用）
```

## 来源范式

- `export_gltf.py` 改写自 07 动捕项目组 `verify_fbx.py`（`E:\AI\orca-worktrees\07_AI2Blender\ai2blender_07_00\verify_fbx.py`）：
  - 07 版：FBX 导入→骨骼校验→EEVEE 渲染截图（动捕白模验证）。
  - 05 版：blend→glTF(gb) 导出→校验对象统计→EEVEE 渲染截图（游戏资产进 Godot）。
  - **共用同一套 headless 纪律**：`blender -b --python`、临时相机、EEVEE 渲染、不依赖 GUI/MCP。

## 使用方式

```bash
# 导出 glb 进 Godot
"E:\adobe\Blender 5.2\blender.exe" --background --python blender_assets/scripts/export_gltf.py -- ^
    --input-blend path/to/source.blend ^
    --output-gltf build/asset.glb ^
    --output-shot build/asset_preview.png

# Godot 里导入 .glb：直接拖进场景，或 GLTFDocument.load()
```

## 与 Godot 的对接约定（glTF→Godot）

- **Y-up**：Blender 导出 `export_yup=True`，Godot 默认 Y-up，避免轴向翻转。
- **单位**：Blender 米 = Godot 米，`export_scale=1.0` 即可；若源文件用厘米，设 `export_scale=0.01`。
- **骨骼命名**：Godot 骨名直接读 glTF，保持一致即可。
- **验证**：导出后必跑 `--output-shot` 出图，肉眼确认无穿模/无黑屏（headless 截图走临时相机 + EEVEE，避免被遮挡拍全黑——见踩坑文档）。

## 实测结论（2026-11-11）

- 本机 `blender_mcp.py`（ahujasid/mcp-for-blender v1.8）已装但未启用，`--background` 下 server 拒启动，**纯 headless 无法 AI 直驱**。
- 因此 05 共用资产**走脚本批处理路线**（`blender -b --python`），零依赖、稳，与 07 对齐。
- 若要上 AI 直驱（mcp），需 GUI/虚拟显示 + 启用插件，待老泡儿点头再议（见 blender-mcp 实测纪要）。

详见：
- `E:/AI/AI_Memory/知识库/05-AI2Godot-游戏开发/blender-mcp实测-2026-11-11.md`
- `E:/AI/AI_Memory/知识库/05-AI2Godot-游戏开发/05x07-blender协同提案-2026-11-11.md`（旧口径，已按新关系作废）
