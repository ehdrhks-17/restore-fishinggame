extends Node

# Player Stats
var nickname: String = "강태공"
var level: int = 1
var exp: int = 0
var qua: int = 1000 # 시작 기본 자금 (쿠아)

# Equipped Gear
var equipped_rod: String = "basic_rod"
var equipped_reel: String = "basic_reel"
var equipped_line: String = "basic_line"
var equipped_bait: String = "basic_bait"

# Inventory & Aquarium
var inventory: Array = [
	{"id": "basic_rod", "type": "rod", "name": "대나무 낚싯대"},
	{"id": "basic_reel", "type": "reel", "name": "목제 실타래 릴"},
	{"id": "basic_line", "type": "line", "name": "일반 줄 1호"},
	{"id": "basic_bait", "type": "bait", "name": "지렁이 미끼", "quantity": 10}
]

var aquarium_fish: Array = []

# Serialize to Dictionary
func to_dict() -> Dictionary:
	return {
		"nickname": nickname,
		"level": level,
		"exp": exp,
		"qua": qua,
		"equipped_rod": equipped_rod,
		"equipped_reel": equipped_reel,
		"equipped_line": equipped_line,
		"equipped_bait": equipped_bait,
		"inventory": inventory,
		"aquarium_fish": aquarium_fish
	}

# Deserialize from Dictionary
func from_dict(dict: Dictionary) -> void:
	if dict.has("nickname"): nickname = dict["nickname"]
	if dict.has("level"): level = dict["level"]
	if dict.has("exp"): exp = dict["exp"]
	if dict.has("qua"): qua = dict["qua"]
	if dict.has("equipped_rod"): equipped_rod = dict["equipped_rod"]
	if dict.has("equipped_reel"): equipped_reel = dict["equipped_reel"]
	if dict.has("equipped_line"): equipped_line = dict["equipped_line"]
	if dict.has("equipped_bait"): equipped_bait = dict["equipped_bait"]
	if dict.has("inventory"): inventory = dict["inventory"]
	if dict.has("aquarium_fish"): aquarium_fish = dict["aquarium_fish"]
