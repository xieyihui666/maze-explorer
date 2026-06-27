extends Node

const PORT = 42069
const CONNECT_TIMEOUT = 10.0

var is_host: bool = false
var is_multi: bool = false
var peer: ENetMultiplayerPeer
var upnp: UPNP
var public_ip: String = ""
var upnp_ok: bool = false

signal upnp_status(success: bool, message: String)
signal connection_failed(reason: String)

func start_host():
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT)
	if err != OK:
		push_error("创建服务器失败: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_multi = true
	_setup_upnp()

func start_client(address: String):
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, PORT)
	if err != OK:
		connection_failed.emit("无法连接到 " + address + ":" + str(PORT))
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_multi = true

func stop():
	_remove_upnp()
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

func _setup_upnp():
	upnp = UPNP.new()
	upnp.discover_ipv6 = false
	var err = upnp.discover()
	if err != OK:
		upnp_ok = false
		upnp_status.emit(false, "UPnP 不可用，请手动在路由器转发端口 " + str(PORT))
		return
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(_on_upnp_discovery_done)

func _on_upnp_discovery_done():
	if not upnp or not is_host:
		return
	if upnp.get_device_count() == 0:
		upnp_ok = false
		upnp_status.emit(false, "未发现 UPnP 设备，请手动转发端口 " + str(PORT))
		return
	var result = upnp.add_port_mapping(PORT, 0, "MazeExplorer", "UDP")
	if result != OK:
		upnp_ok = false
		upnp_status.emit(false, "端口映射失败，请手动转发端口 " + str(PORT))
		return
	upnp_ok = true
	public_ip = upnp.query_external_address()
	if public_ip == "":
		_fetch_public_ip_http()
	else:
		upnp_status.emit(true, public_ip)

func _fetch_public_ip_http():
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_ip_result.bind(http))
	http.request("https://api.ipify.org")

func _on_http_ip_result(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if code == 200:
		public_ip = body.get_string_from_utf8().strip_edges()
		if public_ip != "":
			upnp_status.emit(true, public_ip)
			return
	upnp_status.emit(true, "端口已开放")

func _remove_upnp():
	if upnp and upnp_ok:
		upnp.delete_port_mapping(PORT, "UDP")
	upnp = null
