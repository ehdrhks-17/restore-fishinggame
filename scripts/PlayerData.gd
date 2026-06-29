extends Node

# Player Stats
var nickname: String = "강태공"
var level: int = 1
var exp: int = 0
var qua: int = 1000 # 시작 기본 자금 (쿠아)

# Equipped Gear & Boat
var equipped_rod: String = "starter_rod"
var equipped_reel: String = "basic_reel"
var equipped_line: String = "basic_line"
var equipped_bait: String = "starter_lure"
var equipped_boat: String = "rubber_boat"
var unlocked_boats: Array = ["rubber_boat"]

# Inventory & Aquarium
var inventory: Array = [
	{"id": "starter_rod", "type": "rod", "name": "초보 낚싯대"},
	{"id": "starter_lure", "type": "lure", "name": "초보 루어", "quantity": -1}
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
		"equipped_boat": equipped_boat,
		"unlocked_boats": unlocked_boats,
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
	if dict.has("equipped_boat"): equipped_boat = dict["equipped_boat"]
	if dict.has("unlocked_boats"): unlocked_boats = dict["unlocked_boats"]
	if dict.has("inventory"): inventory = dict["inventory"]
	if dict.has("aquarium_fish"): aquarium_fish = dict["aquarium_fish"]

	# --- Save File Migration ---
	var has_starter_rod = false
	var has_starter_lure = false
	var cleaned_inventory = []
	
	for item in inventory:
		var item_id = item.get("id", "")
		if item_id == "bamboo_rod" or item.get("name") == "대나무 낚싯대":
			continue
		if item_id == "worm_bait" or item.get("name") == "지렁이 미끼":
			continue
		
		if item_id == "starter_rod":
			has_starter_rod = true
		if item_id == "starter_lure":
			has_starter_lure = true
			item["quantity"] = -1 # Enforce infinite
		cleaned_inventory.append(item)
		
	if not has_starter_rod:
		cleaned_inventory.append({"id": "starter_rod", "type": "rod", "name": "초보 낚싯대"})
	if not has_starter_lure:
		cleaned_inventory.append({"id": "starter_lure", "type": "lure", "name": "초보 루어", "quantity": -1})
		
	inventory = cleaned_inventory
	
	if equipped_rod == "bamboo_rod" or equipped_rod == "starter" or not _has_item_in_inventory(equipped_rod):
		equipped_rod = "starter_rod"
	if equipped_bait == "worm_bait" or equipped_bait == "starter" or not _has_item_in_inventory(equipped_bait):
		equipped_bait = "starter_lure"

func _has_item_in_inventory(item_id: String) -> bool:
	for item in inventory:
		if item.get("id") == item_id:
			return true
	return false
