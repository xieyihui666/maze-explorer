extends Node2D

var explored = []
var maze_ref = null
var maze_sz = 0
var player_pos = Vector2.ZERO
var exit_cell = Vector2i.ZERO
var cell_sz = 48
var items_ref: Array = []

func update_data(expl: Array, mz: Array, sz: int, pp: Vector2, exit: Vector2i, c: int, itms: Array):
	explored = expl
	maze_ref = mz
	maze_sz = sz
	player_pos = pp
	exit_cell = exit
	cell_sz = c
	items_ref = itms
	var px = int(pp.x / c)
	var py = int(pp.y / c)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cx = px + dx
			var cy = py + dy
			if cx >= 0 and cx < sz and cy >= 0 and cy < sz:
				explored[cy][cx] = true
	queue_redraw()

func _draw():
	if maze_ref == null:
		return
	var s = 180.0 / float(maze_sz)
	for y in range(maze_sz):
		for x in range(maze_sz):
			if not explored[y][x]:
				draw_rect(Rect2(x * s, y * s, s, s), Color(0.85, 0.85, 0.85, 1))
			elif maze_ref[y][x]:
				draw_rect(Rect2(x * s, y * s, s, s), Color(0.5, 0.55, 0.7, 0.9))
			else:
				draw_rect(Rect2(x * s, y * s, s, s), Color(0.85, 0.8, 0.7, 0.7))
	draw_rect(Rect2(exit_cell.x * s, exit_cell.y * s, s, s), Color(0.2, 1, 0.3, 1))
	for item in items_ref:
		var ix = int(item["pos"].x / cell_sz)
		var iy = int(item["pos"].y / cell_sz)
		if explored[iy][ix]:
			var ic: Color
			match item["type"]:
				0: ic = Color.CYAN
				1: ic = Color.GREEN
				2: ic = Color.RED
				3: ic = Color.MAGENTA
				4: ic = Color.YELLOW
			draw_circle(Vector2(ix * s + s/2, iy * s + s/2), max(1.5, s * 0.3), ic)
	var px = player_pos.x / cell_sz * s
	var py = player_pos.y / cell_sz * s
	draw_circle(Vector2(px, py), max(3.0, s * 0.5), Color(0, 0.8, 1, 1))
