"""
05 部门 Blender 共用资产脚本：导出 glTF/glb 进 Godot（headless 兼容）。

来源范式：07 动捕项目组 verify_fbx.py（FBX 导入→骨骼校验→headless 渲染截图）。
收编为 05 共用资产（05 是工具正主，07 项目组等共用）。

用法：
    blender --background --python export_gltf.py -- \
        --input-blend <src.blend> \
        --collection <可选: 只导出某集合> \
        --output-gltf <out.glb> \
        --output-shot <验证截图.png 可选>

设计纪律（沿用 07 踩坑，详见 docs/blender_shared_pitfalls.md）：
- 全 headless 跑（`blender -b`），不依赖 GUI/MCP（本机无显示环境）。
- 视口截图走临时相机 + EEVEE/Workbench 渲染，避免被遮挡拍全黑。
- 导出 glTF 用 Blender 内置 glTF 2.0 插件（无需外部依赖）。
"""

import argparse
import sys
import bpy
import os


def _log(msg: str) -> None:
    print(f"[05-export_gltf] {msg}")


def main() -> None:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]

    ap = argparse.ArgumentParser(description="05 共用：Blender→glTF(gb) 导出 + 验证截图")
    ap.add_argument("--input-blend", required=True, help="源 .blend 路径")
    ap.add_argument("--collection", default="", help="只导出指定集合（留空=全部）")
    ap.add_argument("--output-gltf", required=True, help="输出 .gltf 或 .glb 路径")
    ap.add_argument("--output-shot", default="", help="可选：验证截图 PNG 路径")
    ap.add_argument("--scale", type=float, default=1.0, help="导出缩放（Godot 用米，Blender 常用米，默认 1.0）")
    args = ap.parse_args(argv)

    # ---- 开干净工程 ----
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _log(f"open {args.input_blend}")
    bpy.ops.wm.open_mainfile(filepath=args.input_blend)

    # ---- 选集合（可选） ----
    if args.collection:
        for col in bpy.data.collections:
            col.hide_viewport = (col.name != args.collection)
        _log(f"仅可见集合: {args.output_gltf} 禁用其它")

    # ---- 校验导出对象 ----
    mesh_count = sum(1 for o in bpy.data.objects if o.type == "MESH")
    arm_count = sum(1 for o in bpy.data.objects if o.type == "ARMATURE")
    _log(f"对象统计: MESH={mesh_count} ARMATURE={arm_count}")

    # ---- 导出 glTF 2.0 ----
    out_dir = os.path.dirname(os.path.abspath(args.output_gltf))
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    export_cfg = {
        "filepath": args.output_gltf,
        "export_format": "GLB" if args.output_gltf.lower().endswith(".glb") else "GLTF_SEPARATE",
        "use_selection": False,
        "export_yup": True,            # Godot 默认 Y-up，Blender 导出选 Y-up 最稳
        "export_apply": True,          # 应用修饰器/变换，Godot 里不炸
        "export_scale": args.scale,
    }
    _log(f"export glTF -> {args.output_gltf}")
    bpy.ops.export_scene.gltf(**export_cfg)
    _log(f"DONE export: {os.path.getsize(args.output_gltf)} bytes")

    # ---- 验证截图（headless 兼容，临时相机 + EEVEE）----
    if args.output_shot:
        shot_dir = os.path.dirname(os.path.abspath(args.output_shot))
        if shot_dir and not os.path.isdir(shot_dir):
            os.makedirs(shot_dir, exist_ok=True)
        scene = bpy.context.scene
        scene.render.engine = 'BLENDER_EEVEE'
        scene.render.image_settings.file_format = 'PNG'
        scene.render.filepath = args.output_shot
        scene.render.resolution_x = 1280
        scene.render.resolution_y = 720
        cam = bpy.data.cameras.new("VerifyCam")
        cam_obj = bpy.data.objects.new("VerifyCam", cam)
        scene.collection.objects.link(cam_obj)
        scene.camera = cam_obj
        # 把相机摆到能看全场景的位置（粗略：沿 -Z 后退 + 抬高）
        cam_obj.location = (0, -4, 2)
        cam_obj.rotation_euler = (1.2, 0, 0)
        light = bpy.data.lights.new("VerifyLight", 'SUN')
        light_obj = bpy.data.objects.new("VerifyLight", light)
        scene.collection.objects.link(light_obj)
        light_obj.location = (3, -3, 5)
        bpy.ops.render.render(write_still=True)
        _log(f"DONE shot -> {args.output_shot}")


if __name__ == "__main__":
    main()
