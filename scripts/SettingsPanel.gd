extends Control

var display_presets = [
	{"name": "1920x1080", "w": 1920, "h": 1080},
	{"name": "1280x720",  "w": 1280, "h": 720},
	{"name": "2560x1440", "w": 2560, "h": 1440},
	{"name": "3840x2160", "w": 3840, "h": 2160},
]
var display_mode_names = ["窗口", "窗口化全屏", "全屏"]
var display_preset_idx = 0
var display_mode_idx = 2

signal closed

func _ready():
	# 按钮连接
	$VBox/ResRow/ResLeftBtn.pressed.connect(func(): _cycle_res(-1))
	$VBox/ResRow/ResRightBtn.pressed.connect(func(): _cycle_res(1))
	$VBox/ModeRow/ModeLeftBtn.pressed.connect(func(): _cycle_mode(-1))
	$VBox/ModeRow/ModeRightBtn.pressed.connect(func(): _cycle_mode(1))
	$VBox/BtnRow/SaveBtn.pressed.connect(_save_and_close)
	$VBox/BtnRow/CancelBtn.pressed.connect(_cancel)
	visible = false

func open():
	# 同步当前设置
	display_preset_idx = 0
	display_mode_idx = 2
	for i in range(display_presets.size()):
		if display_presets[i]["w"] == GameState.display_width and display_presets[i]["h"] == GameState.display_height:
			display_preset_idx = i
			break
	display_mode_idx = GameState.window_mode
	if display_mode_idx < 0 or display_mode_idx >= display_mode_names.size():
		display_mode_idx = 2
	_update_labels()
	visible = true

func _cycle_res(dir: int):
	display_preset_idx = wrapi(display_preset_idx + dir, 0, display_presets.size())
	_update_labels()

func _cycle_mode(dir: int):
	display_mode_idx = wrapi(display_mode_idx + dir, 0, display_mode_names.size())
	_update_labels()

func _update_labels():
	$VBox/ResRow/ResValue.text = display_presets[display_preset_idx]["name"]
	$VBox/ModeRow/ModeValue.text = display_mode_names[display_mode_idx]

func _save_and_close():
	var p = display_presets[display_preset_idx]
	GameState.display_width = p["w"]
	GameState.display_height = p["h"]
	GameState.window_mode = display_mode_idx
	GameState.save_display_settings()
	GameState.apply_display()
	visible = false
	closed.emit()

func _cancel():
	visible = false
	closed.emit()

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		_save_and_close()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB):
		_cancel()
	elif event.is_action_pressed("move_left"):
		_cycle_res(-1)
	elif event.is_action_pressed("move_right"):
		_cycle_res(1)
	elif event.is_action_pressed("move_up"):
		_cycle_mode(-1)
	elif event.is_action_pressed("move_down"):
		_cycle_mode(1)
