extends Node
class_name Leaderboard

const SAVE_PATH = "user://leaderboard.json"

static func load_scores() -> Dictionary:
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {"10": [], "30": [], "60": []}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return {"10": [], "30": [], "60": []}
	return data

static func save_score(mode: int, name: String, score: int):
	var data = load_scores()
	var key = str((mode + 1) * 10)
	if not data.has(key):
		data[key] = []
	data[key].append({"name": name, "score": score})
	data[key].sort_custom(func(a, b): return a["score"] > b["score"])
	if data[key].size() > 10:
		data[key] = data[key].slice(0, 10)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

static func get_top(mode: int) -> Array:
	var data = load_scores()
	var key = str((mode + 1) * 10)
	if not data.has(key):
		return []
	return data[key].slice(0, 10)
