# Planet — 大鱼吃小鱼的星球演化游戏

太空版「大鱼吃小鱼」：从一颗小陨石开始，靠引力吸收周围的碎石不断长大，
依次演化 **陨石 → 流星 → 行星 → 恒星 → 白矮星 → 黑洞**。

## 运行

```bash
# 用编辑器打开
Godot_v4.7.2-stable_win64.exe --path projects/planet -e

# 直接跑
Godot_v4.7.2-stable_win64.exe --path projects/planet
```

## 操作

| 输入 | 作用 |
|---|---|
| `WASD` / 方向键 | 移动（屏幕相对方向） |
| `Esc` | 退出 |
| `R` | 死亡后重开 |

## 玩法

- 靠近比你**小**的碎片会把它吸进来，质量增加。
- 撞到比你**大**的碎片会掉质量；陨石阶段质量归零就结束。
- 大小接近的会互相弹开。
- 质量跨过阈值就进入下一演化阶段，外观随之变化。

### 演化阶梯

| 阶段 | 名称 | 质量阈值 |
|---|---|---|
| 0 | Asteroid 陨石 | 0 |
| 1 | Meteor 流星 | 5 |
| 2 | Planet 行星 | 22 |
| 3 | Star 恒星 | 70 |
| 4 | White Dwarf 白矮星 | 180 |
| 5 | Black Hole 黑洞 | 400 |

## 实现要点

### 星球外观：全程序化着色器

`shaders/planet.gdshader` 一个着色器覆盖全部六个阶段，靠 `stage` uniform 切换：

- **3D 值噪声 + FBM** 在球面方向上采样，生成无缝的大陆/海洋分布。
- 高度值 `h` 走一条颜色渐变：深海 → 浅海 → 沙滩 → 草地 → 森林 → 岩石 → 雪。
- **阶段覆盖**：
  - 陨石/流星：裸岩 + 陨石坑（噪声做环状凹陷）
  - 恒星：颗粒状对流 + 临边昏暗（limb darkening），避免渲染成一坨死白
  - 白矮星：蓝白高频噪声 + 强临边昏暗
  - 黑洞：黑色圆盘 + 边缘吸积盘辉光（`rim^7` 做锐利光环）
- **大气辉光**用 fresnel 边缘光近似，不需要额外的壳层几何体。

### 生长与相机

- 半径 `base + sqrt(mass) * k`，用 `sqrt` 让前期成长感明显、后期不至于爆炸。
- 相机距离随半径线性拉远（`radius * 6.5 + 9`），保证任何阶段都在画面内。

### 引力与吞并

- `world.gd` 每帧对每块碎片施加指向玩家的力，强度按距离衰减，在 `gravity_radius` 外失效。
- 碰撞判定不是靠物理引擎，而是**手动算距离**：`dist < planet_radius + debris_radius` 就算接触。
  这样规则明确、不依赖碰撞层配置，也避免了刚体互相弹飞的抖动。
- 吞并条件是 `大的 >= 小的 * 1.12`，即必须明显更大才能吃；接近的会弹开。

## 开发辅助

两个只在带参数时激活的脚本，用来让 AI 自己验证：

```bash
# 截图某个演化阶段
Godot_v4.7.2-stable_win64_console.exe --path . -- --stage=3 --shot --shot-path=E:/out.png

# 玩法自测：自动吃 18 秒，报告质量增长和阶段变化
Godot_v4.7.2-stable_win64_console.exe --path . -- --selftest
```

`--selftest` 的输出形如：

```
[selftest] start mass=1.00
[selftest] end mass=167.11 grew=true stages=[1, 2, 3]
[selftest] RESULT: PASS
```

## 文件结构

```
projects/planet/
├── project.godot
├── scenes/
│   ├── main.tscn      # 根场景：环境、灯光、相机
│   └── planet.tscn    # 玩家星球
├── scripts/
│   ├── main.gd        # 组装世界、处理重开
│   ├── planet.gd      # 玩家：移动、生长、阶段、相机
│   ├── debris.gd      # 碎片
│   ├── world.gd       # 生成、引力、吞并规则
│   ├── hud.gd         # 阶段名 / 质量显示
│   ├── dev_screenshot.gd
│   └── selftest.gd
└── shaders/
    └── planet.gdshader
```
