# Maze Explorer - 会话交接文档

**日期：** 2026-06-27
**GitHub：** https://github.com/xieyihui666/maze-explorer
**本地路径：** C:\Users\35345\xief\maze-game
**Godot：** Godot 4.7 Mono 位于桌面 `Godot_v4.7-stable_mono_win64`
**AGENTS.md：** 项目根目录有完整的项目知识库（PR #1 贡献者编写）

## 已完成功能

### 三种模式
| 模式 | 时间 | 地图 | 道具 | 状态 |
|------|------|------|------|------|
| 速通 | 10分钟 | 80x80 | 无 | ✅ 完整 |
| 标准 | 30分钟 | 140x140 | 12个 | ✅ 完整 |
| 深度 | 60分钟 | 200x200 | 20个 | ⚠️ 怪物未做 |

### 6种道具（按键1-6）
- 1=⚡加速 2=⌛加时 3=🔨击碎墙壁(3x3) 4=🍀全图5秒 5=👁永久视野+2 6=✈穿墙2秒

### 多人联机（ENet P2P，端口42069）
- 单人/联机合作/联机比赛 三种玩法
- 房间码6位数字，好友系统（昵称+IP）
- 迷宫/位置/计时/道具/断线全部同步
- E键传送队友，比赛模式先到者赢

### 作弊码（Z键面板，Enter确认）
xieyihui chuanqiang shunyi shubiao shengli daoju time N

### 画面设置（Tab键，PR #1新增）
- 分辨率切换（1920/1280/2560/3840）
- 窗口/全屏模式切换
- 设置持久化到 user://display_settings.json

### 快捷键
- Esc: 暂停/退出面板
- V: 游戏说明
- Tab: 画面设置
- N: 修改昵称（最多6字）
- 左键点小地图: 放大全览 → Esc关闭

### godot-mcp
- 已安装到 C:\Users\35345\xief\godot-mcp
- opencode.json 已配置，opencode启动时自动加载
- mcp_interaction_server.gd 在 scripts/ 备用

## 未完成工作

1. **60分钟怪物系统** — 完全未开发，GameState.enemy_count 已有但未用
2. **道具选择** — Start.gd 有 show_item_select 变量但功能未完成
3. **排行榜写入** — Leaderboard.save_score 从未被调用，通关不记分
4. **FogOverlay.gd 闲置** — ShaderMaterial 迷雾代码在但未被场景引用

## 环境信息
- Git 已安装（C:\Program Files\Git\bin）
- Node.js 已安装（C:\Users\35345\AppData\Local\nodejs\node-v20.18.0-win-x64）
- 推送需用 `git -c http.sslVerify=false push`（SSL被拦截）
- 有一个未使用的 stash（可通过 `git stash list` 查看）
