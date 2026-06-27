extends Node
class_name PlayerProfile

const NICK_PATH = "user://nickname.txt"

static func get_nickname() -> String:
	var f = FileAccess.open(NICK_PATH, FileAccess.READ)
	if f:
		var name = f.get_as_text().strip_edges()
		f.close()
		if name != "":
			return name
	var default_name = "探" + str(randi_range(10000, 99999))
	set_nickname(default_name)
	return default_name

static func set_nickname(name: String):
	var f = FileAccess.open(NICK_PATH, FileAccess.WRITE)
	f.store_string(name)
	f.close()
