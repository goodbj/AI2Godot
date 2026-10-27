#!/usr/bin/env python3
"""AI2Godot 回归跑批：一条命令跑完 planet 实验里所有 headless 自测。

设计目标是给 AI（或人）一个「改完代码 → 一条命令 → 绿/红」的循环，
不需要盯着游戏窗口看。所有检查都来自游戏内的 dev 开关（见
projects/planet/README.md），本脚本只负责调用与汇总。

用法：

    python ai/scripts/run_checks.py                 # 全部检查（含截图）
    python ai/scripts/run_checks.py --quick         # 只跑逻辑检查（几秒）
    python ai/scripts/run_checks.py --no-shots      # 跳过需要真实渲染窗口的截图
    python ai/scripts/run_checks.py --godot /path/to/Godot
    python ai/scripts/run_checks.py --list          # 只列出会跑哪些检查

Godot 可执行文件按以下顺序查找：
    --godot 参数  >  环境变量 GODOT_PATH  >  .mcp.json 里的 GODOT_PATH  >  PATH
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_PROJECT = REPO / "projects" / "planet"
DEFAULT_SHOTS = REPO / "build" / "shots"

# 可能出现在 PATH 里的名字（Linux/macOS 包名、Windows 常见安装名）。
PATH_CANDIDATES = ["godot", "godot4", "Godot", "godot.exe"]


def find_godot(explicit: str | None) -> Path:
    """Locate the Godot binary. Kept in sync with .mcp.json on purpose."""
    if explicit:
        p = Path(explicit).expanduser()
        if not p.exists():
            raise SystemExit(f"--godot 指向的文件不存在: {p}")
        return p

    env = os.environ.get("GODOT_PATH")
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return p

    mcp = REPO / ".mcp.json"
    if mcp.exists():
        try:
            cfg = json.loads(mcp.read_text(encoding="utf-8"))
            servers = cfg.get("mcpServers", {})
            for name in ("godot", *servers.keys()):
                entry = servers.get(name) or {}
                candidate = (entry.get("env") or {}).get("GODOT_PATH")
                if candidate:
                    p = Path(candidate).expanduser()
                    if p.exists():
                        return p
        except (json.JSONDecodeError, OSError):
            pass  # .mcp.json 只是线索，坏了就继续往下找

    for name in PATH_CANDIDATES:
        found = shutil.which(name)
        if found:
            return Path(found)

    raise SystemExit(
        "找不到 Godot 可执行文件。请用 --godot 指定，或设置 GODOT_PATH，"
        "或把它写进 .mcp.json 的 mcpServers.godot.env.GODOT_PATH。"
    )


def build_checks(args: argparse.Namespace) -> list[dict]:
    """The check list. Each entry becomes one Godot process."""
    checks: list[dict] = []

    # 1) 操作映射：证明移动方向跟着镜头走，而不是写死的屏幕轴。
    for yaw in (0, 45, 135, 200):
        checks.append({
            "name": f"dirtest yaw={yaw}",
            "args": ["--dirtest", f"--yaw={yaw}"],
            "headless": True,
            "marker": "[dirtest]",
            "timeout": 40,
        })

    # 2) 玩法：18s 内能不能靠吃碎片长大（保证核心循环没坏）。
    checks.append({
        "name": "selftest (18s)",
        "args": ["--selftest"],
        "headless": True,
        "marker": "[selftest]",
        "timeout": 60,
    })

    # 3) 平衡性：60s 能不能一路进化到黑洞（慢，--quick 时跳过）。
    if not args.quick:
        checks.append({
            "name": "selftest-long (60s)",
            "args": ["--selftest-long"],
            "headless": True,
            "marker": "[selftest]",
            "timeout": 150,
        })

    # 4) 六级进化外观：截图存盘，由 AI 直接看图判断渲染有没有坏。
    if not args.quick and not args.no_shots:
        shots = Path(args.shots_dir)
        shots.mkdir(parents=True, exist_ok=True)
        stages = [
            (0, "asteroid", 0, 20),
            (1, "meteor", 40, 26),
            (2, "planet", 135, 55),
            (3, "star", 200, 30),
            (4, "white_dwarf", 300, 45),
            (5, "black_hole", 20, 12),
        ]
        for stage, label, yaw, pitch in stages:
            out = shots / f"stage{stage}_{label}.png"
            checks.append({
                "name": f"shot stage={stage} {label}",
                "args": [
                    "--shot", f"--shot-path={out.as_posix()}",
                    f"--stage={stage}", f"--yaw={yaw}", f"--pitch={pitch}",
                ],
                # 截图需要真实渲染上下文，--headless 下截不到画面。
                "headless": False,
                "marker": "[shot]",
                "timeout": 60,
                "artifact": str(out),
            })

    return checks


def run_check(godot: Path, project: Path, check: dict) -> tuple[bool, str, list[str]]:
    cmd = [str(godot), "--path", str(project)]
    if check["headless"]:
        cmd.append("--headless")
    cmd.append("--")
    cmd.extend(check["args"])

    started = time.time()
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=check["timeout"],
        )
    except subprocess.TimeoutExpired:
        return False, f"TIMEOUT after {check['timeout']}s", []

    lines = [
        line.strip()
        for line in (proc.stdout + "\n" + proc.stderr).splitlines()
        if check["marker"] in line or "SCRIPT ERROR" in line
    ]
    elapsed = time.time() - started

    passed = any("RESULT: PASS" in line for line in lines)
    if not passed and check["marker"] == "[shot]":
        passed = "err=0" in proc.stdout and proc.returncode == 0

    note = f"{elapsed:.1f}s, exit={proc.returncode}"
    return passed, note, lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--godot", help="Godot 可执行文件路径")
    ap.add_argument("--project", default=str(DEFAULT_PROJECT), help="Godot 工程目录")
    ap.add_argument("--shots-dir", default=str(DEFAULT_SHOTS), help="截图输出目录（已 gitignore）")
    ap.add_argument("--quick", action="store_true", help="只跑逻辑检查，跳过 60s 平衡测试与截图")
    ap.add_argument("--no-shots", action="store_true", help="跳过截图检查")
    ap.add_argument("--list", action="store_true", help="只列出将要执行的检查")
    args = ap.parse_args()

    project = Path(args.project).expanduser().resolve()
    if not (project / "project.godot").exists():
        raise SystemExit(f"不是 Godot 工程: {project}")

    checks = build_checks(args)
    if args.list:
        for c in checks:
            print(f"{c['name']:<28} headless={c['headless']} timeout={c['timeout']}s")
        return 0

    godot = find_godot(args.godot)
    print(f"godot   : {godot}")
    print(f"project : {project}")
    print(f"checks  : {len(checks)}")
    print("-" * 68)

    failures = 0
    for check in checks:
        passed, note, lines = run_check(godot, project, check)
        status = "PASS" if passed else "FAIL"
        print(f"[{status}] {check['name']:<28} {note}")
        if not passed:
            failures += 1
            for line in lines:
                print(f"       {line}")

    print("-" * 68)
    print(f"{len(checks) - failures}/{len(checks)} checks passed")
    if failures:
        print("RESULT: FAIL")
        return 1
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
