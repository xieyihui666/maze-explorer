# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-27

## OVERVIEW

俯视角迷宫探索单人游戏。纯 GDScript（**非** C# Mono，尽管 project.godot 残留 `[dotnet]` 段）。Forked from [xieyihui666/maze-explorer](https://github.com/xieyihui666/maze-explorer)。

## STRUCTURE

```
maze-explorer/
├── project.godot              # 主场景 res://scenes/Start.tscn；viewport 1920x1080；stretch mode canvas_items
├── scenes/
│   ├── Start.tscn             # 模式选择菜单（3 行 Panel），UI 几乎全部在 .tscn 里硬编码
│   └── MazeGame.tscn          # 游戏主场景；HUD 子树含 MiniMap/BigMap/PauseMenu/HelpPanel/CheatPanel/GameOver
└── scripts/
    ├── Start.gd               # 模式选择交互、键鼠双轨；设 GameState.* 后 change_scene → MazeGame
    ├── GameState.gd           # 全局静态状态（AutoLoad），跨场景传输模式/尺寸/时限
    ├── MazeGame.gd            # 游戏循环核心：迷宫生成 + 玩家移动 + 视野迷雾 + 道具 + 作弊 + A* 寻路
    ├── MiniMap.gd             # 右上角 180x180 小地图，Node2D 自绘 _draw
    ├── BigMap.gd              # 点击小地图弹出的大地图全览，Node2D 自绘 _draw
    ├── FogOverlay.gd          # ShaderMaterial 黑色径向迷雾，跟随玩家
    └── Leaderboard.gd         # 排行榜持久化，static methods + class_name；user://leaderboard.json
```

 GameState 通过 AutoLoad 注册（场景 tree 中不出现，靠 `class_name GameState` 全局可见）。

## WHERE TO LOOK

| 任务 | 位置 | 备注 |
|---|---|---|
| 改玩家移动手感 | `MazeGame.gd` `_process` L136-146 | 速度常量 260；分轴 `is_passable` 检测 4 角 ±10px |
| 改迷宫算法 | `MazeGame.gd` `generate_maze` L40-97 | 递归回溯栈式；额外打通 3% 墙减少孤岛 |
| 改可见范围 | `MazeGame.gd` `VIEW_RANGE`/`VIEW_RANGE_PERM` L4,26 + `_draw` L190 | 曼哈顿距离 ≤ VIEW_RANGE+PERM 显示；作弊 `shengli`/道具不受此限 |
| 改道具效果 | `MazeGame.gd` `use_item` L362-381 + `ItemType` enum L28 | 5 种，`match` 多分支 |
| 改作弊码 | `MazeGame.gd` `exec_cheat` L467-487 | 全部用拼音命名，硬编码字符串比较 |
| 改小地图绘制 | `MiniMap.gd` `_draw` L29-56 | 180px 固定尺寸；s = 180/maze_sz |
| 改大地图绘制 | `BigMap.gd` `_draw` L20-68 | 居中适配屏幕；**未探索=黑色迷雾** |
| 改迷雾 shader | `FogOverlay.gd` L6-15 | inner 170 outer 220；alpha 0.92 黑 |
| 加新 UI 控件 | `.tscn` 直接编辑优先 | 脚本只接管动态逻辑；静态 UI 全在场景文件 |
| 排行榜读写 | `Leaderboard.gd` 静态方法 | mode 0/1/2 → key "10"/"30"/"60" |
| 输入绑定 | `project.godot` `[input]` 段 | move_left/right/up/down + p1_ultimate + ui_accept |

## CONVENTIONS

- 中文化第一：所有面向玩家的字符串（UI/HUD/作弊提示）中文。代码注释也中文首选。
- 节点路径硬编码：`$HUD/MiniMap` `$Camera2D` `$HUD/PauseMenu/RestartBtn` —— 没用 `@onready` 缓存，每次访问查 tree。规模小够用，**scale up 时需重构**。
- 颜色直接 `Color(r,g,b,a)` inline，不抽常量。改皮肤需全局 grep。
- 迷宫使用二维 `Array` of `Array[bool]`：`maze[y][x] == true` 表示**墙**（注意语义反直觉）。
- 输入处理全在 `_input(event)` 单点分发（按优先级抢先 return）：`cheat` > `pause` > `help` > `show_map` > `mouse` > `keys`。
- Attr dictionary 风格做 ad-hoc 数据：`{"pos": Vector2, "type": int}` —— 没用强类型 resource。
- `match` 语句**必须**用多行块格式（GDScript 4 不支持单行 `pattern: stmt`），见 `MiniMap.gd` L47-57、`BigMap.gd` L53-63、`MazeGame.gd` L366-380 / L355-360。
- indent **tab-only**；混用会触发 GDScript parser 报错。

## ANTI-PATTERNS (THIS PROJECT)

- **不要**在 GDScript 里写 `match X: 0: foo; 1: bar` 这种单行块 —— parser 会报 "Expected end of statement after expression, found ':' instead"。
- **不要**给 `BigMap` 类型 Node2D 加不透明 ColorRect 子节点当背景 —— 子节点绘制在父 `_draw()` 之上，会完全遮挡 _draw 输出（历史 bug：原 `MapBG` ColorRect 不可见地盖住整张迷宫，使点击小地图只显全屏单色）。
- **不要** `as any`/`@ts-ignore`（无 TypeScript，但同理：不要在 GDScript 里用 `Variant` 逃避类型 —— 仅在 MCP/transport 边界允许）。
- **不要**删 `.godot/` 或 `.codegraph/` 目录 —— 前者是 Godot 生成的 import 缓存，后者是 LSP 索引。
- **不要**改 `[dotnet]` 段或 `.csproj` —— 项目是纯 GDScript，那段是上游残留，删除会触发编辑器 importer 重导。

## UNIQUE STYLES

- 作弊码用**拼音字符串**而非英文（`xieyihui`/`chuanqiang`/`shunyi`/`shubiao`/`shengli`/`time N`）。这是原作者设计意图，新增作弊码沿用此风格。
- 三种模式用 emoji+模式名硬编码在 `Start.gd` `modes` 数组（⚡🎯🏰）。模式 ID = 数组 index，与 `GameState.mode` 与 Leaderboard key (10/30/60) 都有映射，改模式数量需同步 3 处。
- 迷宫尺寸按时间模式固定：80 / 140 / 200。`generate_maze` 是 O(n²) 内存，200 已是上限 —— 加大需评估 Array 嵌套与 `_draw` 全遍历性能。
- 缩放：`Camera2D.zoom = Vector2(1.8, 1.8)` 硬编码，无运行时调整。FOV-style 缩放需另作 feature。

## COMMANDS

```bash
# 用 godot-mcp 或直接命令行启动
godot --path "G:\dev\maze-explorer"
# headless 验证脚本语法（不启动游戏）
godot --headless --check-only --script scripts/XXX.gd --path "G:\dev\maze-explorer"
# headless 加载场景验证 parser error
godot --headless --quit-after 80 --path "G:\dev\maze-explorer" "res://scenes/MazeGame.tscn"
# 同步上游
git fetch upstream && git merge upstream/master
```

## NOTES

- `project.godot` 残留 `[dotnet] project/assembly_name="Maze Explorer"` —— 但没有任何 .cs / .csproj，README 误称 "需要 Godot 4.7 Mono + .NET 8.0 SDK"。**实际只需 Godot 4.x 标准 build**。
- `game_over` 流程：`game_over = true` → `_process` 早 return → `update_hud` 显示 GameOver panel → Enter 键 → `change_scene_to_file("res://scenes/Start.tscn")`。**没有计分写入 Leaderboard**！目前 Leaderboard 仅 Start 界面查询，从未写入。
- `display/window/size/mode=3` 即启动即全屏。`MazeGame._ready` 与 `Start._ready` 都再调一次 `window_set_mode(FULLSCREEN)` —— 多余但无害。
- `Leaderboard.gd` `save_score(mode, name, score)` **从未被调用** —— 死代码，得分胜利时不持久化。要补这块需在 `MazeGame.gd` `game_over` 分支加调用并弹输入框取名。
- `mouse_guide` 作弊启用右键寻路，但走的是 `move_to_click` 全屏坐标 → `find_path` A* → 自动行走，期间禁用键盘。再次按作弊切换后才解放。
- `path` 数组是 `Vector2[]` 世界坐标点，`path_index` 推进；接近 (<4px) 自动切下一段。空 `path` 示玩家自由控。
- BigMap 颜色方案：未探索 = 黑色 `(0,0,0,1)` 迷雾；已探索墙 `(0.1,0.12,0.3)` 深蓝；已探索路 `(0.72,0.66,0.52)` 亮米。出口绿 `(0.2,0.9,0.3)`。如改动需同步 README 描述的"放大全览"语义。
- 三个 maze_*.png 是迷宫不同尺寸的预览图（10/30/60 min），非运行时资产。