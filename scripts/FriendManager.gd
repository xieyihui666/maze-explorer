extends Node
class_name FriendManager

const PATH = "user://friends.json"

static func get_friends() -> Array:
	var f = FileAccess.open(PATH, FileAccess.READ)
	if not f:
		return []
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data == null or not data is Array:
		return []
	return data

static func add_friend(name: String, ip: String):
	var friends = get_friends()
	for fr in friends:
		if fr["ip"] == ip:
			return
	friends.append({"name": name, "ip": ip})
	save(friends)

static func remove_friend(ip: String):
	var friends = get_friends()
	var new_list = []
	for fr in friends:
		if fr["ip"] != ip:
			new_list.append(fr)
	save(new_list)

static func save(friends: Array):
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(friends, "\t"))
	f.close()
