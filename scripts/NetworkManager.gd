extends Node

const PORT = 42069

var is_host: bool = false
var is_multi: bool = false
var peer: ENetMultiplayerPeer

func start_host():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_multi = true

func start_client(address: String):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_multi = true

func stop():
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_multi = false

static func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			if not ip.begins_with("172.1") and not ip.begins_with("172.0"):
				return ip
	return "127.0.0.1"
