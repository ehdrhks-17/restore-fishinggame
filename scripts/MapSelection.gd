extends Control

@onready var region_container: VBoxContainer = $LeftPanel/ScrollContainer/VBoxContainer
@onready var sub_map_panel: Panel = $SubMapPanel
@onready var sub_map_title: Label = $SubMapPanel/Title
@onready var sub_map_container: VBoxContainer = $SubMapPanel/ScrollContainer/VBoxContainer
@onready var korea_map: Control = $KoreaMap

# Solid vector colors since polygons draw the map directly
const COLOR_NORMAL = Color(0.2, 0.25, 0.3, 1.0)
const COLOR_HIGHLIGHT = Color(0.45, 0.65, 0.95, 1.0)

# Groups representing metropolitan cities and multi-part province fragments
const REGION_GROUPS = {
	"seoul": ["seoul"],
	"incheon": ["incheon"],
	"gyeonggi": ["gyeonggi"],
	"gangwon": ["gangwon"],
	"chungbuk": ["chungbuk"],
	"chungnam": ["chungnam", "daejeon", "sejong"],
	"jeonbuk": ["jeonbuk"],
	"jeonnam": ["jeonnam", "gwangju"],
	"gyeongbuk": ["gyeongbuk", "daegu"],
	"gyeongnam": ["gyeongnam", "busan", "ulsan"],
	"jeju": ["jeju"]
}

var _hovered_region_key: String = ""
var _active_highlight_polys: Array[Polygon2D] = []

# Performance caches for collision checks
var _poly_bounds: Dictionary = {}
var _collision_polys: Dictionary = {}

func _ready() -> void:
	sub_map_panel.visible = false
	reset_map_colors()
	
	# Generate performance caches for collision checks
	_initialize_performance_caches()
	
	# Connect region buttons
	for button in region_container.get_children():
		if button is Button:
			button.pressed.connect(_on_region_pressed.bind(button.name))
			button.mouse_entered.connect(_on_region_hovered.bind(button.name))
			button.mouse_exited.connect(_on_region_unhovered)
			
	# Back button
	$BackBtn.pressed.connect(_on_back_pressed)

func _initialize_performance_caches() -> void:
	for poly in korea_map.get_children():
		if poly is Polygon2D:
			# 1. Bounding box cache
			var min_x = INF
			var max_x = -INF
			var min_y = INF
			var max_y = -INF
			for p in poly.polygon:
				if p.x < min_x: min_x = p.x
				if p.x > max_x: max_x = p.x
				if p.y < min_y: min_y = p.y
				if p.y > max_y: max_y = p.y
			_poly_bounds[poly.name] = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
			
			# 2. Collision polygon cache
			_collision_polys[poly.name] = poly.polygon



func reset_map_colors() -> void:
	for poly in korea_map.get_children():
		if poly is Polygon2D:
			poly.color = COLOR_NORMAL
	_active_highlight_polys.clear()



func highlight_province(region_key: String) -> void:
	# Only reset previously highlighted polygons
	for poly in _active_highlight_polys:
		if is_instance_valid(poly):
			poly.color = COLOR_NORMAL
	_active_highlight_polys.clear()
	
	if not REGION_GROUPS.has(region_key):
		return
		
	# Apply highlight to targets and cache them
	var targets = REGION_GROUPS[region_key]
	for poly in korea_map.get_children():
		if poly is Polygon2D:
			for target in targets:
				if poly.name == target or poly.name.begins_with(target + "_"):
					poly.color = COLOR_HIGHLIGHT
					_active_highlight_polys.append(poly)
					break

func _on_region_hovered(region_key: String) -> void:
	_hovered_region_key = region_key
	highlight_province(region_key)

func _on_region_unhovered() -> void:
	_hovered_region_key = ""
	if sub_map_panel.visible:
		# Keep current selected region highlighted
		for key in MapData.REGIONS:
			if MapData.REGIONS[key]["name"] == sub_map_title.text:
				highlight_province(key)
				return
	highlight_province("")


var _time_since_last_check: float = 0.0
const CHECK_INTERVAL: float = 0.05 # 20 FPS (every 50ms)
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var global_pos = get_global_mouse_position()
	# If mouse hasn't moved, do nothing
	if global_pos == _last_mouse_pos:
		return
	_last_mouse_pos = global_pos
	
	_time_since_last_check += delta
	if _time_since_last_check >= CHECK_INTERVAL:
		_time_since_last_check = 0.0
		_update_hover()

func _update_hover() -> void:
	var global_pos = get_global_mouse_position()
	# Ignore direct map inputs if hovering left buttons scroll or sub map panels
	if global_pos.x < 310:
		return
	if sub_map_panel.visible and global_pos.x > 930:
		return
		
	var local_pos = korea_map.get_local_mouse_position()
	# Check inside KoreaMap bounding container size
	if not Rect2(Vector2.ZERO, korea_map.size).has_point(local_pos):
		if _hovered_region_key != "" and not _is_hovering_button():
			_on_region_unhovered()
		return
		
	# Check collision with administrative polygons
	var found_region = ""
	for poly in korea_map.get_children():
		if poly is Polygon2D:
			# Fast bounding box check first
			var bounds = _poly_bounds.get(poly.name, Rect2())
			if bounds.has_point(local_pos):
				# Point check on pre-simplified collision polygon
				var col_poly = _collision_polys.get(poly.name, poly.polygon)
				if Geometry2D.is_point_in_polygon(local_pos, col_poly):
					var base_name = poly.name
					if "_" in base_name:
						base_name = base_name.split("_")[0]
						
					# Trace base name back to region group
					for key in REGION_GROUPS:
						if base_name in REGION_GROUPS[key]:
							found_region = key
							break
					if found_region != "":
						break
					
	if found_region != "":
		if _hovered_region_key != found_region:
			_hovered_region_key = found_region
			highlight_province(found_region)
	else:
		# Mouse in water
		if _hovered_region_key != "" and not _is_hovering_button():
			_on_region_unhovered()

func _input(event: InputEvent) -> void:
	# Click handling (instant reaction, not throttled)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = get_global_mouse_position()
		if global_pos.x < 310:
			return
		if sub_map_panel.visible and global_pos.x > 930:
			return
			
		var local_pos = korea_map.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, korea_map.size).has_point(local_pos):
			return
			
		for poly in korea_map.get_children():
			if poly is Polygon2D:
				var bounds = _poly_bounds.get(poly.name, Rect2())
				if bounds.has_point(local_pos):
					var col_poly = _collision_polys.get(poly.name, poly.polygon)
					if Geometry2D.is_point_in_polygon(local_pos, col_poly):
						var base_name = poly.name
						if "_" in base_name:
							base_name = base_name.split("_")[0]
						for key in REGION_GROUPS:
							if base_name in REGION_GROUPS[key]:
								_on_region_pressed(key)
								return


func _is_hovering_button() -> bool:
	for button in region_container.get_children():
		if button is Button and button.get_global_rect().has_point(get_global_mouse_position()):
			return true
	return false

func _on_region_pressed(region_key: String) -> void:
	if not MapData.REGIONS.has(region_key):
		return
		
	var region_info = MapData.REGIONS[region_key]
	sub_map_title.text = region_info["name"]
	sub_map_panel.visible = true
	
	highlight_province(region_key)
			
	# Clear old sub-maps UI elements
	for child in sub_map_container.get_children():
		child.queue_free()
		
	if region_info["sub_maps"].is_empty():
		var label = Label.new()
		label.text = "현재 준비 중인 지역입니다."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_map_container.add_child(label)
		return

	# Build sub-maps list based on level constraints
	for map in region_info["sub_maps"]:
		var map_item = HBoxContainer.new()
		map_item.custom_minimum_size = Vector2(0, 50)
		
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var is_locked = PlayerData.level < map["min_level"]
		if is_locked:
			btn.text = "%s (Lv.%d 필요)" % [map["name"], map["min_level"]]
			btn.disabled = true
		else:
			btn.text = "%s (입장하기)" % map["name"]
			btn.pressed.connect(_on_sub_map_selected.bind(map["id"]))
			
		map_item.add_child(btn)
		sub_map_container.add_child(map_item)

func _on_sub_map_selected(map_id: String) -> void:
	print("낚시터 입장 시도: ", map_id)
	get_tree().change_scene_to_file("res://scenes/FishingSpot.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/WorldMapSelection.tscn")
