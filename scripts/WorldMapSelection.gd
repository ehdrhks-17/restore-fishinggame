extends Control

@onready var world_map: Control = $WorldMap
@onready var korea_btn: Button = $LeftPanel/ScrollContainer/VBoxContainer/KoreaBtn
@onready var back_btn: Button = $BackBtn

# Solid vector colors
const COLOR_NORMAL = Color(0.2, 0.25, 0.3, 1.0)
const COLOR_HIGHLIGHT = Color(0.45, 0.65, 0.95, 1.0)

const REGION_GROUPS = {
	"korea": ["korea"],
	"japan": ["japan", "japan_2", "japan_3"],
	"china": ["china", "china_2"],
	"usa": ["usa", "usa_2", "usa_3"]
}

var _hovered_region_key: String = ""
var _active_highlight_polys: Array[Polygon2D] = []

# Performance caches for collision checks
var _poly_bounds: Dictionary = {}
var _collision_polys: Dictionary = {}

func _ready() -> void:
	# Reset map colors and build cache
	reset_map_colors()
	_initialize_performance_caches()
	
	# Connect buttons
	korea_btn.pressed.connect(_on_korea_pressed)
	korea_btn.mouse_entered.connect(func(): highlight_province("korea"))
	korea_btn.mouse_exited.connect(func(): highlight_province(""))
	
	back_btn.pressed.connect(_on_back_pressed)

func _initialize_performance_caches() -> void:
	for poly in world_map.get_children():
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
			_collision_polys[poly.name] = poly.polygon

func reset_map_colors() -> void:
	for poly in world_map.get_children():
		if poly is Polygon2D:
			poly.color = COLOR_NORMAL
	_active_highlight_polys.clear()

func highlight_province(region_key: String) -> void:
	for poly in _active_highlight_polys:
		if is_instance_valid(poly):
			poly.color = COLOR_NORMAL
	_active_highlight_polys.clear()
	
	if not REGION_GROUPS.has(region_key):
		return
		
	var targets = REGION_GROUPS[region_key]
	for poly in world_map.get_children():
		if poly is Polygon2D:
			for target in targets:
				if poly.name == target or poly.name.begins_with(target + "_"):
					poly.color = COLOR_HIGHLIGHT
					_active_highlight_polys.append(poly)
					break

var _time_since_last_check: float = 0.0
const CHECK_INTERVAL: float = 0.05 # 20 FPS (every 50ms)
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var global_pos = get_global_mouse_position()
	if global_pos == _last_mouse_pos:
		return
	_last_mouse_pos = global_pos
	
	_time_since_last_check += delta
	if _time_since_last_check >= CHECK_INTERVAL:
		_time_since_last_check = 0.0
		_update_hover()

func _update_hover() -> void:
	var global_pos = get_global_mouse_position()
	if global_pos.x < 310:
		return
		
	var local_pos = world_map.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, world_map.size).has_point(local_pos):
		if _hovered_region_key != "":
			_hovered_region_key = ""
			highlight_province("")
		return
		
	var found_region = ""
	for poly in world_map.get_children():
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
							found_region = key
							break
					if found_region != "":
						break
						
	if found_region != "":
		# Only allow hovering/interaction for active regions (currently Korea)
		if found_region == "korea":
			if _hovered_region_key != found_region:
				_hovered_region_key = found_region
				highlight_province(found_region)
		else:
			# If hovered over disabled region, clear highlight
			if _hovered_region_key != "":
				_hovered_region_key = ""
				highlight_province("")
	else:
		if _hovered_region_key != "":
			_hovered_region_key = ""
			highlight_province("")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = get_global_mouse_position()
		if global_pos.x < 310:
			return
			
		var local_pos = world_map.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, world_map.size).has_point(local_pos):
			return
			
		for poly in world_map.get_children():
			if poly is Polygon2D:
				var bounds = _poly_bounds.get(poly.name, Rect2())
				if bounds.has_point(local_pos):
					var col_poly = _collision_polys.get(poly.name, poly.polygon)
					if Geometry2D.is_point_in_polygon(local_pos, col_poly):
						var base_name = poly.name
						if "_" in base_name:
							base_name = base_name.split("_")[0]
						if base_name == "korea":
							_on_korea_pressed()
							return

func _on_korea_pressed() -> void:
	print("세계지도: 대한민국 선택됨 -> 한국 지도로 이동")
	get_tree().change_scene_to_file("res://scenes/MapSelection.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
