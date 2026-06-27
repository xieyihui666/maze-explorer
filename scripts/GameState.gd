extends Node
class_name GameState

static var mode: int = 0
static var maze_size: int = 60
static var time_limit: int = 600
static var treasure_count: int = 5
static var coin_count: int = 50
static var item_count: int = 0
static var enemy_count: int = 0

static var score: int = 0
static var player_collected: int = 0
static var time_remaining: float = 0
static var game_over: bool = false

static var player_speed_mult: float = 1.0
static var fog_boost: float = 0.0
static var magnet_active: bool = false
static var score_mult: float = 1.0

static func reset():
	score = 0
	player_collected = 0
	time_remaining = time_limit
	game_over = false
	player_speed_mult = 1.0
	fog_boost = 0.0
	magnet_active = false
	score_mult = 1.0
