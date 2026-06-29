extends Node3D

enum Mode {
	BOATING,
	FISHING
}

enum State {
	IDLE,
	CASTING,
	WAITING_FOR_BITE,
	BITE,
	FIGHTING,
	CATCH_SCREEN,
	FAILED_SCREEN
}

var current_mode: Mode = Mode.BOATING
var current_state: State = State.IDLE

# Time configuration
var game_time_seconds: float = 7.0 * 3600.0 # Starts at 07:00 AM

# Boat configuration
const BOATS = {
	"rubber_boat": {
		"name": "고무 보트",
		"max_speed": 30.0, # km/h
		"acceleration": 15.0,
		"steer_speed": 1.6,
		"color": Color(0.8, 0.4, 0.1),
		"scale": Vector3(1.0, 1.0, 1.0)
	},
	"wood_boat": {
		"name": "나무 보트",
		"max_speed": 45.0,
		"acceleration": 18.0,
		"steer_speed": 1.3,
		"color": Color(0.55, 0.35, 0.15),
		"scale": Vector3(1.1, 1.0, 1.1)
	}
}

# Boat Physics
var boat_velocity: Vector3 = Vector3.ZERO
var boat_rotation_y: float = 0.0
var current_speed_kph: float = 0.0

# Shop items list
const DOCK_SHOP_ITEMS = {
	"rods": [
		{
			"id": "zinc_rod",
			"name": "아연 낚싯대",
			"desc": "장력 저항성 강화. 최대 장력: 135",
			"price": 500
		}
	],
	"lures": [
		{
			"id": "daddy_lure",
			"name": "아빠 루어",
			"desc": "영구 사용. 입질 대기 시간 35% 단축",
			"price": 200
		},
		{
			"id": "squishy_lure",
			"name": "말랑말랑 루어",
			"desc": "영구 사용. 포획하는 대어 크기 25% 증가",
			"price": 350
		},
		{
			"id": "handmade_lure",
			"name": "수제 루어",
			"desc": "영구 사용. 포획 시 획득 경험치 50% 증가",
			"price": 600
		}
	],
	"baits": [
		{
			"id": "worm_bait",
			"name": "지렁이 미끼",
			"desc": "5개입. 생물 미끼. 포획 시 획득 쿠아 50% 증가 및 입질 대기 시간 30% 단축",
			"price": 50
		},
		{
			"id": "shrimp_bait",
			"name": "새우 미끼",
			"desc": "5개입. 생물 미끼. 대어(길이) 50% 증가 및 획득 쿠아 100% 증가",
			"price": 100
		}
	],
	"boats": [
		{
			"id": "wood_boat",
			"name": "나무 보트",
			"desc": "나무 재질의 보트. 최고속도: 45 km/h",
			"price": 800
		}
	]
}

# Fishing Parameters
var tension: float = 0.0
var max_tension: float = 100.0
var distance: float = 0.0
var fish_stamina: float = 100.0
var max_fish_stamina: float = 100.0

# Fish Stats
var active_fish_name: String = ""
var active_fish_length: float = 0.0
var active_fish_weight: float = 0.0
var active_fish_reward: int = 0
var active_fish_exp: int = 0
var fish_pull_force: float = 0.0
var fish_angry_timer: float = 0.0
var is_fish_angry: bool = false

# UI Nodes
@onready var ui_canvas: CanvasLayer = $UICanvas
@onready var top_left_panel: PanelContainer = $UICanvas/TopLeftPanel
@onready var money_label: Label = $UICanvas/TopLeftPanel/VBox/Money
@onready var top_right_panel: PanelContainer = $UICanvas/TopRightPanel
@onready var clock_label: Label = $UICanvas/TopRightPanel/ClockLabel
@onready var bottom_left_panel: PanelContainer = $UICanvas/BottomLeftPanel
@onready var btn1: Button = $UICanvas/BottomLeftPanel/VBox/Btn1
@onready var btn2: Button = $UICanvas/BottomLeftPanel/VBox/Btn2
@onready var btn3: Button = $UICanvas/BottomLeftPanel/VBox/Btn3
@onready var btn4: Button = $UICanvas/BottomLeftPanel/VBox/Btn4
@onready var bottom_right_panel: PanelContainer = $UICanvas/BottomRightPanel
@onready var boating_container: VBoxContainer = $UICanvas/BottomRightPanel/VBox/BoatingContainer
@onready var fishing_container: VBoxContainer = $UICanvas/BottomRightPanel/VBox/FishingContainer
@onready var speed_label: Label = $UICanvas/BottomRightPanel/VBox/BoatingContainer/SpeedLabel
@onready var btn_open_map: Button = $UICanvas/BottomRightPanel/VBox/BoatingContainer/BtnOpenMap
@onready var minimap_container: AspectRatioContainer = $UICanvas/BottomRightPanel/VBox/BoatingContainer/MinimapContainer
@onready var lure_label: Label = $UICanvas/BottomRightPanel/VBox/FishingContainer/LureBox/LureLabel
@onready var rod_label: Label = $UICanvas/BottomRightPanel/VBox/FishingContainer/RodBox/RodLabel
@onready var btn_click: Button = $UICanvas/BottomRightPanel/VBox/FishingContainer/CastMeterContainer/BtnClick
@onready var cast_bar: ProgressBar = $UICanvas/BottomRightPanel/VBox/FishingContainer/CastMeterContainer/CastBarControl/CastBar
@onready var cast_bar_label: Label = $UICanvas/BottomRightPanel/VBox/FishingContainer/CastMeterContainer/CastBarControl/CastBarLabel
@onready var prompt_label: Label = $UICanvas/PromptLabel
@onready var panel_fight: Panel = $UICanvas/FightPanel
@onready var progress_tension: ProgressBar = $UICanvas/FightPanel/TensionBar
@onready var progress_stamina: ProgressBar = $UICanvas/FightPanel/StaminaBar
@onready var label_distance: Label = $UICanvas/FightPanel/DistanceLabel
@onready var panel_result: Panel = $UICanvas/ResultPanel
@onready var label_result_text: Label = $UICanvas/ResultPanel/ResultText
@onready var btn_confirm_result: Button = $UICanvas/ResultPanel/ConfirmBtn
@onready var popups_container: Control = $UICanvas/Popups

# 3D Objects
@onready var boat: CharacterBody3D = $Boat
@onready var boat_mesh: MeshInstance3D = $Boat/MeshInstance3D
@onready var dock: StaticBody3D = $Dock
@onready var dock_portal: Area3D = $DockPortal
@onready var bobber: MeshInstance3D = $Bobber
@onready var camera: Camera3D = $Camera3D

# Timers/Casting
var bite_wait_time: float = 0.0
var bite_timer: float = 0.0
var reaction_timer: float = 0.0
var bobber_base_y: float = 0.1
var cast_start_pos: Vector3 = Vector3.ZERO
var cast_target_pos: Vector3 = Vector3.ZERO

# Minimap Drawing Node
var minimap_node: Control

# Portal State
var is_in_portal: bool = false

# Mouse Navigation State
var is_dragging_mouse: bool = false
var mouse_accumulated_steer: float = 0.0

# Casting Gauge State
enum CastState { IDLE, POWER, DIRECTION }
var current_cast_state: CastState = CastState.IDLE
var cast_value: float = 0.0
var cast_oscillate_speed: float = 2.2
var cast_oscillate_dir: float = 1.0
var selected_power: float = 0.0
var selected_direction: float = 0.0

# Fish Pool
const FISH_POOL = [
	{"name": "피라미", "min_len": 8.0, "max_len": 15.0, "weight_mult": 0.05, "base_qua": 50, "base_exp": 10, "difficulty": 1.0},
	{"name": "붕어", "min_len": 15.0, "max_len": 35.0, "weight_mult": 0.15, "base_qua": 100, "base_exp": 25, "difficulty": 1.5},
	{"name": "잉어", "min_len": 35.0, "max_len": 70.0, "weight_mult": 0.4, "base_qua": 250, "base_exp": 50, "difficulty": 2.2},
	{"name": "메기", "min_len": 40.0, "max_len": 80.0, "weight_mult": 0.5, "base_qua": 400, "base_exp": 80, "difficulty": 3.0},
	{"name": "가물치", "min_len": 55.0, "max_len": 95.0, "weight_mult": 0.7, "base_qua": 600, "base_exp": 120, "difficulty": 4.2}
]

func _ready() -> void:
	# Ensure PlayerData variables are fallback-safe
	if not "equipped_boat" in PlayerData or PlayerData.equipped_boat == "rubber":
		PlayerData.set("equipped_boat", "rubber_boat")
	if not "unlocked_boats" in PlayerData or PlayerData.unlocked_boats.has("rubber"):
		PlayerData.set("unlocked_boats", ["rubber_boat"])
		
	# Apply boat visual details
	_apply_boat_type(PlayerData.get("equipped_boat"))
	
	# Apply glass UI styles
	_apply_custom_theme()
	
	# Setup Minimap
	_setup_minimap()
	
	# Connect base buttons
	btn_confirm_result.pressed.connect(_on_confirm_result_pressed)
	btn_open_map.pressed.connect(_open_large_map)
	btn_click.pressed.connect(_on_btn_click_pressed)
	
	# Connect Dock Portal signals
	dock_portal.body_entered.connect(_on_portal_entered)
	dock_portal.body_exited.connect(_on_portal_exited)
	
	# Setup mode
	_switch_mode(Mode.BOATING)
	
	# Initial positioning
	boat.global_position = Vector3(1.5, 0.2, 8.0) # Start next to the portal
	boat_rotation_y = PI # facing -Z direction
	boat.rotation.y = boat_rotation_y
	bobber.visible = false

func _process(delta: float) -> void:
	# 1. Update Game Clock
	game_time_seconds += delta * 6.0 # 10s real time = 1 min game time (6.0x)
	var hrs = int(game_time_seconds / 3600) % 24
	var mins = int(game_time_seconds / 60) % 60
	clock_label.text = "⏰ %02d:%02d" % [hrs, mins]
	
	# Update Money Label
	money_label.text = "💰 %s 쿠아" % _format_number(PlayerData.qua)
	
	# 2. Physics & Navigation depending on current mode
	if current_mode == Mode.BOATING:
		_process_boating_movement(delta)
		_process_camera_follow(delta)
		_update_prompt_text()
	elif current_mode == Mode.FISHING:
		_process_fishing_loop(delta)
		_process_casting_gauge(delta)
		# Smooth camera focus towards the water in front of boat
		var target_cam_pos = boat.global_position + boat.global_transform.basis * Vector3(0, 3.0, 5.0)
		camera.global_position = camera.global_position.lerp(target_cam_pos, delta * 3.0)
		camera.look_at(boat.global_position + boat.global_transform.basis * Vector3(0, 0, -8))

func _process_casting_gauge(delta: float) -> void:
	if current_state == State.IDLE:
		if current_cast_state == CastState.POWER or current_cast_state == CastState.DIRECTION:
			cast_value += cast_oscillate_dir * cast_oscillate_speed * delta
			if cast_value >= 1.0:
				cast_value = 1.0
				cast_oscillate_dir = -1.0
			elif cast_value <= 0.0:
				cast_value = 0.0
				cast_oscillate_dir = 1.0
			cast_bar.value = cast_value * 100.0

func _input(event: InputEvent) -> void:
	if current_mode == Mode.BOATING:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					# Check if clicking over any active UI panels
					var is_over_ui = false
					for panel in [top_left_panel, top_right_panel, bottom_left_panel, bottom_right_panel]:
						if panel.visible and panel.get_global_rect().has_point(event.global_position) and panel.modulate.a > 0.1:
							is_over_ui = true
							break
					if not is_over_ui:
						for popup in popups_container.get_children():
							if popup is Control and popup.visible and popup.get_global_rect().has_point(event.global_position):
								is_over_ui = true
								break
					if not is_over_ui:
						is_dragging_mouse = true
						mouse_accumulated_steer = 0.0
				else:
					is_dragging_mouse = false
					mouse_accumulated_steer = 0.0
		elif event is InputEventMouseMotion and is_dragging_mouse:
			# Accumulate drag input. Drag left (relative.x < 0) -> turn left (steer > 0)
			mouse_accumulated_steer += -event.relative.x * 0.25
	elif current_mode == Mode.FISHING and current_state == State.IDLE:
		if event.is_action_pressed("ui_accept"):
			_on_btn_click_pressed()

func _setup_minimap() -> void:
	minimap_node = Control.new()
	minimap_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap_node.draw.connect(_draw_minimap)
	minimap_container.add_child(minimap_node)

func _draw_minimap() -> void:
	var size = minimap_node.size
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 5.0
	
	# Draw glass panel bg
	minimap_node.draw_circle(center, radius, Color(0.04, 0.08, 0.15, 0.8))
	minimap_node.draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.45, 0.85, 0.6), 2.0)
	
	# Grid crosshairs
	minimap_node.draw_line(Vector2(0, center.y), Vector2(size.x, center.y), Color(0.2, 0.45, 0.85, 0.2), 1.0)
	minimap_node.draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), Color(0.2, 0.45, 0.85, 0.2), 1.0)
	
	# Draw Dock (starts at X=-5, Z=8)
	var du = center.x + (-5.0 / 200.0) * (radius * 2.0)
	var dv = center.y + (8.0 / 200.0) * (radius * 2.0)
	minimap_node.draw_rect(Rect2(du - 4, dv - 6, 8, 12), Color(0.55, 0.4, 0.25, 0.8))
	
	# Draw Dock Portal (next to the dock)
	var pu_portal = center.x + (-1.8 / 200.0) * (radius * 2.0)
	var pv_portal = center.y + (8.0 / 200.0) * (radius * 2.0)
	minimap_node.draw_circle(Vector2(pu_portal, pv_portal), 5.0, Color(0.15, 0.65, 1.0, 0.5))
	
	# Draw Player Boat
	var pu = center.x + (boat.global_position.x / 200.0) * (radius * 2.0)
	var pv = center.y + (boat.global_position.z / 200.0) * (radius * 2.0)
	
	# Triangled arrow facing rotation direction
	var boat_angle = boat_rotation_y - PI/2 # Align correctly
	var dir = Vector2.from_angle(boat_angle)
	var p1 = Vector2(pu, pv) + dir * 7.0
	var p2 = Vector2(pu, pv) + dir.rotated(deg_to_rad(135)) * 5.0
	var p3 = Vector2(pu, pv) + dir.rotated(deg_to_rad(-135)) * 5.0
	
	minimap_node.draw_polygon(PackedVector2Array([p1, p2, p3]), PackedColorArray([Color(0.9, 0.8, 0.1)]))

func _process_boating_movement(delta: float) -> void:
	var boat_cfg = BOATS[PlayerData.get("equipped_boat")]
	var max_speed = boat_cfg["max_speed"]
	var accel = boat_cfg["acceleration"]
	var steer = boat_cfg["steer_speed"]
	
	# Safety check for mouse release
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_mouse = false
	
	# Get input
	var up = Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or (is_dragging_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var down = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var left = Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right = Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	
	# Steering - Fixed: A (Left) now turns Left, D (Right) now turns Right
	if abs(current_speed_kph) > 1.0:
		var kb_steer = 1.0 if left else (-1.0 if right else 0.0)
		var mouse_steer = clamp(mouse_accumulated_steer, -1.0, 1.0)
		var steer_dir = clamp(kb_steer + mouse_steer, -1.0, 1.0)
		
		# Reverse steer direction when backing up
		if current_speed_kph < 0.0:
			steer_dir *= -1.0
		boat_rotation_y += steer_dir * steer * delta
		boat.rotation.y = boat_rotation_y
		
	# Reset accumulator
	mouse_accumulated_steer = 0.0
		
	# Speed acceleration/deceleration
	if up:
		current_speed_kph += accel * delta
	elif down:
		current_speed_kph -= accel * delta
	else:
		# Inertial drag
		current_speed_kph = move_toward(current_speed_kph, 0.0, 10.0 * delta)
		
	current_speed_kph = clamp(current_speed_kph, -max_speed * 0.3, max_speed)
	speed_label.text = "Speed: %05.1f km/h" % abs(current_speed_kph)
	
	# Translate speed to velocity vector (10 km/h = 2.0 m/s in game scale)
	var speed_mps = (current_speed_kph / 3.6) * 0.8
	var forward_dir = -boat.global_transform.basis.z.normalized()
	boat_velocity = forward_dir * speed_mps
	
	# Use standard Godot character body collision logic
	boat.velocity = boat_velocity
	boat.move_and_slide()
		
	# Redraw minimap icon
	if minimap_node:
		minimap_node.queue_redraw()
		
	# UI Visibility based on boat speed (hides when moving)
	if abs(current_speed_kph) > 1.5:
		bottom_left_panel.modulate.a = move_toward(bottom_left_panel.modulate.a, 0.0, delta * 4.0)
	else:
		bottom_left_panel.modulate.a = move_toward(bottom_left_panel.modulate.a, 1.0, delta * 4.0)

func _process_camera_follow(delta: float) -> void:
	# Behind boat follow logic
	var offset = Vector3(0, 3.5, 6.5)
	var target_pos = boat.global_position + boat.global_transform.basis * offset
	camera.global_position = camera.global_position.lerp(target_pos, delta * 4.0)
	camera.look_at(boat.global_position + Vector3(0, 0.6, 0))

func _update_prompt_text() -> void:
	if is_in_portal:
		prompt_label.text = "⚓ 선착장 포탈 서비스 구역에 정박했습니다! [상점 / 다른 맵 이동]"
	else:
		prompt_label.text = "어디서나 낚시가 가능합니다. 선착장 포탈로 가면 상점을 열거나 이동할 수 있습니다."

# ==========================================
# Portal Trigger Logic
# ==========================================
func _on_portal_entered(body: Node3D) -> void:
	if body == boat:
		is_in_portal = true
		_update_prompt_text()
		_open_portal_menu()

func _on_portal_exited(body: Node3D) -> void:
	if body == boat:
		is_in_portal = false
		_update_prompt_text()
		# Automatically close portal menu if we drive out of it
		_clear_popups()

func _switch_mode(new_mode: Mode) -> void:
	current_mode = new_mode
	popups_container.visible = true
	
	# Disconnect existing button signals safely
	for btn in [btn1, btn2, btn3, btn4]:
		for sig in btn.pressed.get_connections():
			btn.pressed.disconnect(sig.callable)
			
	if current_mode == Mode.BOATING:
		# Reset boat speed
		current_speed_kph = 0.0
		boat_velocity = Vector3.ZERO
		
		# Set UI visibilities
		bottom_right_panel.visible = true
		boating_container.visible = true
		fishing_container.visible = false
		prompt_label.visible = true
		panel_fight.visible = false
		panel_result.visible = false
		bobber.visible = false
		
		# Set button actions (Only swapping equipped items)
		btn1.text = "보트 교환"
		btn1.pressed.connect(_open_boat_swap)
		
		btn2.text = "낚시하기"
		btn2.pressed.connect(_enter_fishing_mode)
		
		btn3.text = "수조 보기"
		btn3.pressed.connect(_open_aquarium)
		
		btn4.text = "도움말"
		btn4.pressed.connect(_open_help)
		
		_update_prompt_text()
		
	elif current_mode == Mode.FISHING:
		# Set UI visibilities
		bottom_right_panel.visible = true
		boating_container.visible = false
		fishing_container.visible = true
		panel_fight.visible = false
		panel_result.visible = false
		
		# Set button actions
		btn1.text = "미끼 교환"
		btn1.pressed.connect(_open_bait_swap)
		
		btn2.text = "낚시대 교환"
		btn2.pressed.connect(_open_rod_swap)
		
		btn3.text = "장소 이동"
		btn3.pressed.connect(_enter_boating_mode)
		
		btn4.text = "도움말"
		btn4.pressed.connect(_open_help)
		
		# Reset fishing and casting states
		current_state = State.IDLE
		current_cast_state = CastState.IDLE
		cast_value = 0.0
		cast_bar.value = 0.0
		cast_bar_label.text = "MIN  |  MAX"
		btn_click.disabled = false
		
		_update_fishing_gear_labels()
		
		prompt_label.text = "CLICK! 버튼이나 스페이스바로 찌를 캐스팅하세요."
		
		# Check bait quantity before setup
		_check_equipped_bait_supply()

func _enter_fishing_mode() -> void:
	_switch_mode(Mode.FISHING)

func _enter_boating_mode() -> void:
	_switch_mode(Mode.BOATING)

# ==========================================
# Fishing Gameplay Loop Logic
# ==========================================
func _process_fishing_loop(delta: float) -> void:
	match current_state:
		State.IDLE:
			# Click button or spacebar handles starting casting
			pass
				
		State.CASTING:
			reaction_timer += delta
			var progress = reaction_timer / 1.5
			if progress >= 1.0:
				_enter_wait_bite()
			else:
				var t = progress
				var height = sin(t * PI) * 3.0
				var horizontal_pos = cast_start_pos.lerp(cast_target_pos, t)
				horizontal_pos.y = bobber_base_y + height
				bobber.global_position = horizontal_pos
				
		State.WAITING_FOR_BITE:
			bite_timer += delta
			var bob_y = bobber_base_y + sin(Time.get_ticks_msec() * 0.005) * 0.05
			bobber.global_position.y = bob_y
			
			if bite_timer >= bite_wait_time:
				_enter_bite()
				
		State.BITE:
			reaction_timer += delta
			bobber.global_position.y = bobber_base_y - 0.4 + sin(Time.get_ticks_msec() * 0.03) * 0.05
			
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_start_fighting()
			elif reaction_timer >= 1.2:
				_fail_fishing("물고기가 미끼를 채서 도망갔습니다!")
				
		State.FIGHTING:
			_process_fighting(delta)

func _check_equipped_bait_supply() -> bool:
	var bait_id = PlayerData.equipped_bait
	var found = false
	var qty = 0
	
	for item in PlayerData.inventory:
		if item["id"] == bait_id:
			found = true
			qty = item.get("quantity", 0)
			break
			
	if not found:
		prompt_label.text = "⚠️ 장착된 미끼/루어가 없습니다! '미끼 교환' 메뉴에서 보유한 루어를 장착하세요."
		return false
	if qty == 0:
		prompt_label.text = "⚠️ 미끼가 소진되었습니다! '미끼 교환' 메뉴에서 다른 미끼나 무제한 루어를 장착하세요."
		return false
	return true

func _start_casting_with_power(power: float, direction: float) -> void:
	if not _check_equipped_bait_supply():
		btn_click.disabled = false
		current_cast_state = CastState.IDLE
		cast_bar.value = 0.0
		cast_bar_label.text = "MIN  |  MAX"
		return
		
	# Consume 1 bait if it's consumable (quantity > 0)
	var bait_id = PlayerData.equipped_bait
	for item in PlayerData.inventory:
		if item["id"] == bait_id:
			var qty = item.get("quantity", -1)
			if qty > 0:
				item["quantity"] = max(0, qty - 1)
			break
	SaveManager.save_game()
	_update_fishing_gear_labels()
	
	# Determine distance from power: 0.0 power = MIN (10m), 1.0 power = MAX (40m)
	distance = lerp(10.0, 40.0, power)
	
	# Calculate target position in 3D relative to boat basis
	# direction is between -1.0 (L) and 1.0 (R)
	var dist_x = direction * 6.0
	cast_start_pos = boat.global_position
	# Scaling the forward distance for visualization in 3D scene (40m maps to ~15.0m visually)
	var visual_dist = distance * 0.35
	cast_target_pos = boat.global_position + boat.global_transform.basis * Vector3(dist_x, bobber_base_y, -visual_dist)
	
	current_state = State.CASTING
	reaction_timer = 0.0
	bobber.visible = true
	bobber.global_position = boat.global_position
	prompt_label.text = "캐스팅 중..."

func _enter_wait_bite() -> void:
	current_state = State.WAITING_FOR_BITE
	bite_timer = 0.0
	
	# Determine base wait duration
	var base_wait = randf_range(4.0, 8.0)
	
	# Apply Lure modifiers
	if PlayerData.equipped_bait == "daddy_lure":
		base_wait *= 0.65 # Daddy Lure cuts waiting time by 35%
	elif PlayerData.equipped_bait == "worm_bait":
		base_wait *= 0.70 # Worm Bait cuts waiting time by 30%
		
	bite_wait_time = max(1.5, base_wait)
	prompt_label.text = "찌가 수면에 던져졌습니다. 입질을 기다리는 중..."

func _enter_bite() -> void:
	current_state = State.BITE
	reaction_timer = 0.0
	prompt_label.text = "💥 입질 감지! 마우스 왼쪽 버튼 클릭!! 💥"

func _start_fighting() -> void:
	current_state = State.FIGHTING
	prompt_label.text = "릴링 시작! 라인 장력을 유지하며 줄을 감아올리세요!"
	panel_fight.visible = true
	
	# Pull random fish
	var fish_template = FISH_POOL.pick_random()
	active_fish_name = fish_template["name"]
	
	# Apply Lure size modifiers
	var size_mult = 1.0
	if PlayerData.equipped_bait == "squishy_lure":
		size_mult = 1.25
	elif PlayerData.equipped_bait == "shrimp_bait":
		size_mult = 1.50 # Shrimp bait increases size by 50%
		
	active_fish_length = randf_range(fish_template["min_len"], fish_template["max_len"]) * size_mult
	active_fish_weight = active_fish_length * fish_template["weight_mult"] * randf_range(0.9, 1.1)
	
	# Compute reward coins & exp
	var reward_mult = 1.0
	if PlayerData.equipped_bait == "worm_bait":
		reward_mult = 1.50 # Worm bait gives 50% more gold
	elif PlayerData.equipped_bait == "shrimp_bait":
		reward_mult = 2.00 # Shrimp bait gives 100% more gold
		
	active_fish_reward = int(fish_template["base_qua"] * size_mult * reward_mult * randf_range(0.9, 1.2))
	
	# Apply Handmade Lure EXP modifier
	var exp_mult = 1.5 if PlayerData.equipped_bait == "handmade_lure" else 1.0
	active_fish_exp = int(fish_template["base_exp"] * size_mult * exp_mult * randf_range(0.9, 1.1))
	
	# Fight settings scaled by fish difficulty
	var diff = fish_template["difficulty"]
	distance = randf_range(30.0, 50.0) * diff
	
	# Adjust parameters based on equipped rod
	var rod = PlayerData.equipped_rod
	max_tension = 100.0
	var player_reel_power = 1.0
	
	if rod == "zinc_rod":
		max_tension = 135.0
	elif rod == "gold_rod":
		max_tension = 160.0
		player_reel_power = 1.3
		
	max_fish_stamina = 100.0 * diff
	fish_stamina = max_fish_stamina
	tension = 20.0
	is_fish_angry = false
	fish_angry_timer = randf_range(2.0, 4.0)
	fish_pull_force = 12.0 * diff

func _process_fighting(delta: float) -> void:
	var is_reeling = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Angry fish states
	fish_angry_timer -= delta
	if fish_angry_timer <= 0.0:
		is_fish_angry = !is_fish_angry
		if is_fish_angry:
			fish_angry_timer = randf_range(1.5, 3.0)
			prompt_label.text = "⚠️ 경고: 물고기가 격하게 도망칩니다! 장력 폭등 주의!"
		else:
			fish_angry_timer = randf_range(3.0, 5.0)
			prompt_label.text = "물고기가 기운을 잃어 차분해졌습니다. 힘껏 릴링하세요!"
			
	var pull_force = fish_pull_force
	if is_fish_angry:
		pull_force *= 1.8
		
	var tension_change = 0.0
	# Rod modifiers to slow down tension spikes
	var tension_mult = 0.75 if PlayerData.equipped_rod == "zinc_rod" else (0.65 if PlayerData.equipped_rod == "gold_rod" else 1.0)
	
	if is_reeling:
		tension_change += 28.0 * tension_mult
		tension_change += pull_force * tension_mult
		distance -= 6.0 * delta * (1.3 if PlayerData.equipped_rod == "gold_rod" else 1.0)
		fish_stamina -= 9.0 * delta * (1.3 if PlayerData.equipped_rod == "gold_rod" else 1.0)
	else:
		tension_change -= 32.0
		distance += (pull_force * 0.25) * delta
		tension_change += pull_force * 0.4
		fish_stamina += 2.5 * delta
		fish_stamina = clamp(fish_stamina, 0.0, max_fish_stamina)
		
	tension += tension_change * delta
	tension = clamp(tension, 0.0, max_tension)
	distance = clamp(distance, 0.0, 200.0)
	
	# UI update
	progress_tension.max_value = max_tension
	progress_tension.value = tension
	progress_stamina.value = (fish_stamina / max_fish_stamina) * 100.0
	label_distance.text = "남은 거리: %.1f m" % distance
	
	if tension >= max_tension * 0.8:
		progress_tension.self_modulate = Color(1.0, 0.2, 0.2)
	else:
		progress_tension.self_modulate = Color(0.2, 0.6, 1.0)
		
	# Bobber 3D placement follows line distance
	bobber.global_position = boat.global_position + boat.global_transform.basis * Vector3(0, bobber_base_y, -distance * 0.2)
	
	# Win / Loss checks
	if distance <= 0.5:
		_success_fishing()
	elif tension >= max_tension:
		_fail_fishing("장력이 과도하여 낚싯줄이 터졌습니다!")
	elif distance >= 120.0:
		_fail_fishing("물고기가 멀리 도망쳐 줄을 다 풀고 탈출했습니다!")

func _success_fishing() -> void:
	current_state = State.CATCH_SCREEN
	panel_fight.visible = false
	bobber.visible = false
	
	# Save details
	PlayerData.qua += active_fish_reward
	PlayerData.exp += active_fish_exp
	
	# Handle Level Ups
	var exp_needed = PlayerData.level * 100
	if PlayerData.exp >= exp_needed:
		PlayerData.level += 1
		PlayerData.exp -= exp_needed
		# Free bonus money on level up
		PlayerData.qua += 200
		prompt_label.text = "🎉 레벨 업 달성! 낚시 능력이 증가했습니다! 🎉"
		
	var log_item = {
		"name": active_fish_name,
		"length": snapped(active_fish_length, 0.1),
		"weight": snapped(active_fish_weight, 0.1),
		"date": Time.get_date_string_from_system()
	}
	PlayerData.aquarium_fish.append(log_item)
	SaveManager.save_game()
	
	label_result_text.text = "🐟 [포획 완료!]\n\n어종: %s\n크기: %.1f cm / 무게: %.1f kg\n\n💰 획득: +%d 쿠아\n⭐ 경험치: +%d EXP" % [
		active_fish_name, active_fish_length, active_fish_weight, active_fish_reward, active_fish_exp
	]
	panel_result.visible = true

func _fail_fishing(reason: String) -> void:
	current_state = State.FAILED_SCREEN
	panel_fight.visible = false
	bobber.visible = false
	
	label_result_text.text = "❌ [물고기를 놓쳤습니다]\n\n원인: %s" % reason
	panel_result.visible = true

func _on_confirm_result_pressed() -> void:
	panel_result.visible = false
	current_state = State.IDLE
	current_cast_state = CastState.IDLE
	cast_bar.value = 0.0
	cast_bar_label.text = "MIN  |  MAX"
	btn_click.disabled = false
	prompt_label.text = "CLICK! 버튼이나 스페이스바로 찌를 캐스팅하세요."
	_check_equipped_bait_supply()

# ==========================================
# UI Popups Building Functions (Clean & Dynamic)
# ==========================================
func _clear_popups() -> void:
	for child in popups_container.get_children():
		child.queue_free()

func _create_popup_frame(title: String, size: Vector2) -> Panel:
	_clear_popups()
	var frame = Panel.new()
	frame.custom_minimum_size = size
	frame.size = size
	# Center anchor
	frame.anchors_preset = Control.PRESET_CENTER
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -size.x / 2
	frame.offset_top = -size.y / 2
	frame.offset_right = size.x / 2
	frame.offset_bottom = size.y / 2
	
	frame.add_theme_stylebox_override("panel", _create_glass_style(Color(0.04, 0.07, 0.12, 0.95), Color(0.2, 0.55, 0.9, 0.7)))
	popups_container.add_child(frame)
	
	# Header Layout
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 30)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.position = Vector2(15, 10)
	header.size = Vector2(size.x - 30, 30)
	frame.add_child(header)
	
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.pressed.connect(_clear_popups)
	_style_button(close_btn, Color(0.4, 0.1, 0.1, 0.7))
	header.add_child(close_btn)
	
	return frame

func _open_help() -> void:
	var frame = _create_popup_frame("도움말 및 게임 방법", Vector2(480, 320))
	
	var text = RichTextLabel.new()
	text.position = Vector2(20, 50)
	text.size = Vector2(440, 250)
	text.bbcode_enabled = true
	text.text = "[color=#5cc5ff][b]⛵ 선박 조작 모드[/b][/color]\n" + \
		"- [b]이동 및 핸들:[/b] 키보드 WASD 또는 방향키\n" + \
		"- 선착장의 파란색 포탈 구역으로 들어가면 상점을 열거나 다른 맵으로 이동할 수 있습니다.\n\n" + \
		"[color=#5cc5ff][b]🎣 낚시 플레이 모드[/b][/color]\n" + \
		"- [b]캐스팅:[/b] 마우스 왼쪽 버튼 클릭으로 던지기\n" + \
		"- [b]입질 시 챔질:[/b] 찌가 가라앉고 느낌표 팝업 시 마우스 왼쪽 버튼 클릭\n" + \
		"- [b]파이팅(릴링):[/b] 마우스 왼쪽 버튼을 길게 누르면 당기며, 떼면 줄을 풉니다.\n" + \
		"- [b]주의:[/b] 장력 바가 꽉 차서 붉은색 임계치를 넘으면 라인이 끊어지니 유의하세요!"
	frame.add_child(text)

func _open_aquarium() -> void:
	var frame = _create_popup_frame("수조 (잡은 물고기 목록)", Vector2(500, 380))
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(460, 310)
	frame.add_child(scroll)
	
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	
	var fish_list = PlayerData.aquarium_fish
	if fish_list.is_empty():
		var empty = Label.new()
		empty.text = "\n\n수조가 텅 비어있습니다.\n어군을 찾아가서 물고기를 낚아 올리세요!"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
		return
		
	# Reverse order list to show recent catches first
	for i in range(fish_list.size() - 1, -1, -1):
		var fish = fish_list[i]
		var container = PanelContainer.new()
		container.add_theme_stylebox_override("panel", _create_glass_style(Color(0.1, 0.15, 0.25, 0.5), Color(0.2, 0.4, 0.7, 0.2)))
		
		var hbox = HBoxContainer.new()
		container.add_child(hbox)
		
		var lbl_name = Label.new()
		lbl_name.text = "🐟 " + fish["name"]
		lbl_name.add_theme_font_size_override("font_size", 15)
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)
		
		var lbl_details = Label.new()
		lbl_details.text = "크기: %.1f cm / 무게: %.1f kg" % [fish["length"], fish["weight"]]
		lbl_details.add_theme_font_size_override("font_size", 14)
		hbox.add_child(lbl_details)
		
		list.add_child(container)

# ==========================================
# Swap Menus: Only list owned items in inventory
# ==========================================
func _open_boat_swap() -> void:
	var frame = _create_popup_frame("보트 관리 및 보관소", Vector2(500, 380))
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 55)
	vbox.size = Vector2(460, 310)
	vbox.add_theme_constant_override("separation", 12)
	frame.add_child(vbox)
	
	var owned_boats = PlayerData.get("unlocked_boats")
	
	if owned_boats.is_empty():
		var lbl = Label.new()
		lbl.text = "보유한 보트가 없습니다."
		vbox.add_child(lbl)
		return
		
	for b_id in BOATS:
		# Only display if user owns/unlocked this boat
		if not b_id in owned_boats:
			continue
			
		var cfg = BOATS[b_id]
		var container = PanelContainer.new()
		container.add_theme_stylebox_override("panel", _create_glass_style(Color(0.08, 0.12, 0.2, 0.6), Color(0.3, 0.5, 0.8, 0.3)))
		
		var hbox = HBoxContainer.new()
		container.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var lbl_name = Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 16)
		info_vbox.add_child(lbl_name)
		
		var lbl_spec = Label.new()
		lbl_spec.text = "최고속도: %d km/h  |  가속도: %d" % [cfg["max_speed"], cfg["acceleration"]]
		lbl_spec.add_theme_font_size_override("font_size", 13)
		lbl_spec.self_modulate = Color(0.7, 0.8, 0.95)
		info_vbox.add_child(lbl_spec)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 35)
		
		var is_equipped = PlayerData.get("equipped_boat") == b_id
		if is_equipped:
			btn.text = "사용 중"
			btn.disabled = true
			_style_button(btn, Color(0.1, 0.35, 0.1, 0.5))
		else:
			btn.text = "탑승하기"
			btn.pressed.connect(_swap_boat.bind(b_id))
			_style_button(btn, Color(0.15, 0.35, 0.6, 0.8))
			
		hbox.add_child(btn)
		vbox.add_child(container)

func _swap_boat(boat_id: String) -> void:
	PlayerData.set("equipped_boat", boat_id)
	SaveManager.save_game()
	_apply_boat_type(boat_id)
	_open_boat_swap() # refresh

func _apply_boat_type(boat_id: String) -> void:
	var cfg = BOATS.get(boat_id)
	if cfg == null:
		return
	# Update 3D boat visual settings
	if boat_mesh:
		boat.scale = cfg["scale"]
		var mat = boat_mesh.get_surface_override_material(0)
		if mat == null:
			mat = StandardMaterial3D.new()
			boat_mesh.set_surface_override_material(0, mat)
		mat.albedo_color = cfg["color"]
		mat.flat_shading = true

func _open_bait_swap() -> void:
	var frame = _create_popup_frame("보유한 미끼/루어 장착", Vector2(500, 400))
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(460, 320)
	frame.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	var owned_lures = []
	var owned_baits = []
	for item in PlayerData.inventory:
		if item.get("type") == "lure":
			owned_lures.append(item)
		elif item.get("type") == "bait":
			owned_baits.append(item)
			
	# Group 1: Permanent Lures (영구 루어)
	var lbl_lures = Label.new()
	lbl_lures.text = "🪱 영구 루어 (소모 없음)"
	lbl_lures.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_lures)
	
	for item in owned_lures:
		_build_bait_item_row(vbox, item)
		
	vbox.add_child(HSeparator.new())
	
	# Group 2: Consumable Live Baits (소모성 생물 미끼)
	var lbl_baits = Label.new()
	lbl_baits.text = "🪱 소모성 생물 미끼"
	lbl_baits.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl_baits)
	
	if owned_baits.is_empty():
		var lbl_empty = Label.new()
		lbl_empty.text = "보유한 생물 미끼가 없습니다."
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl_empty)
	else:
		for item in owned_baits:
			_build_bait_item_row(vbox, item)

func _build_bait_item_row(parent: Control, item: Dictionary) -> void:
	var item_id = item["id"]
	var item_name = item["name"]
	var item_qty = item.get("quantity", -1)
	
	var container = PanelContainer.new()
	container.add_theme_stylebox_override("panel", _create_glass_style(Color(0.08, 0.12, 0.2, 0.6), Color(0.3, 0.5, 0.8, 0.3)))
	
	var hbox = HBoxContainer.new()
	container.add_child(hbox)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var lbl_name = Label.new()
	var qty_text = "무제한" if item_qty == -1 else "%d개" % item_qty
	lbl_name.text = "%s (보유: %s)" % [item_name, qty_text]
	lbl_name.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(lbl_name)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 35)
	var is_equipped = PlayerData.equipped_bait == item_id
	
	if is_equipped:
		btn.text = "장착됨"
		btn.disabled = true
		_style_button(btn, Color(0.1, 0.35, 0.1, 0.5))
	else:
		btn.text = "장착"
		btn.pressed.connect(_equip_bait.bind(item_id))
		_style_button(btn, Color(0.15, 0.35, 0.6, 0.8))
		if item_qty == 0:
			btn.disabled = true
			
	hbox.add_child(btn)
	parent.add_child(container)

func _equip_bait(bait_id: String) -> void:
	PlayerData.equipped_bait = bait_id
	SaveManager.save_game()
	_open_bait_swap()
	_update_fishing_gear_labels()
	if current_mode == Mode.FISHING:
		prompt_label.text = "미끼를 장착했습니다. CLICK! 버튼이나 스페이스바로 캐스팅하세요."

func _open_rod_swap() -> void:
	var frame = _create_popup_frame("보유한 낚싯대 장착", Vector2(500, 380))
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 55)
	vbox.size = Vector2(460, 310)
	vbox.add_theme_constant_override("separation", 12)
	frame.add_child(vbox)
	
	var owned_rods = []
	for item in PlayerData.inventory:
		if item.get("type") == "rod":
			owned_rods.append(item)
			
	for item in owned_rods:
		var r_id = item["id"]
		var r_name = item["name"]
		
		var container = PanelContainer.new()
		container.add_theme_stylebox_override("panel", _create_glass_style(Color(0.08, 0.12, 0.2, 0.6), Color(0.3, 0.5, 0.8, 0.3)))
		
		var hbox = HBoxContainer.new()
		container.add_child(hbox)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)
		
		var lbl_name = Label.new()
		lbl_name.text = r_name
		lbl_name.add_theme_font_size_override("font_size", 16)
		info_vbox.add_child(lbl_name)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 35)
		
		var is_equipped = PlayerData.equipped_rod == r_id
		
		if is_equipped:
			btn.text = "장착됨"
			btn.disabled = true
			_style_button(btn, Color(0.1, 0.35, 0.1, 0.5))
		else:
			btn.text = "장착하기"
			btn.pressed.connect(_equip_rod.bind(r_id))
			_style_button(btn, Color(0.15, 0.35, 0.6, 0.8))
				
		hbox.add_child(btn)
		vbox.add_child(container)

func _equip_rod(rod_id: String) -> void:
	PlayerData.equipped_rod = rod_id
	SaveManager.save_game()
	_open_rod_swap()
	_update_fishing_gear_labels()

# ==========================================
# Dock Portal Menu and Shop (Specific for Han River)
# ==========================================
func _open_portal_menu() -> void:
	var frame = _create_popup_frame("⚓ 선착장 포탈 서비스", Vector2(400, 240))
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(25, 55)
	vbox.size = Vector2(350, 160)
	vbox.add_theme_constant_override("separation", 15)
	frame.add_child(vbox)
	
	var desc = Label.new()
	desc.text = "선착장에 진입하였습니다.\n이용하실 서비스를 선택하세요."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)
	
	var btn_shop = Button.new()
	btn_shop.text = "🛍️ 선착장 상점 이용"
	btn_shop.custom_minimum_size = Vector2(0, 42)
	btn_shop.pressed.connect(_open_dock_shop)
	_style_button(btn_shop, Color(0.15, 0.45, 0.2, 0.8))
	vbox.add_child(btn_shop)
	
	var btn_map = Button.new()
	btn_map.text = "🗺️ 다른 맵으로 이동"
	btn_map.custom_minimum_size = Vector2(0, 42)
	btn_map.pressed.connect(_change_map_scene)
	_style_button(btn_map, Color(0.15, 0.35, 0.6, 0.8))
	vbox.add_child(btn_map)

func _change_map_scene() -> void:
	_clear_popups()
	get_tree().change_scene_to_file("res://scenes/MapSelection.tscn")

func _open_dock_shop() -> void:
	var frame = _create_popup_frame("🛍️ 한강 선착장 상점", Vector2(520, 420))
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(480, 350)
	frame.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	# Section 1: Rods (낚싯대)
	var cat_rods = Label.new()
	cat_rods.text = "🎣 낚싯대 상품"
	cat_rods.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cat_rods)
	
	for item in DOCK_SHOP_ITEMS["rods"]:
		_build_shop_item_row(vbox, item, "rod")
		
	vbox.add_child(HSeparator.new())
	
	# Section 2: Lures (루어)
	var cat_lures = Label.new()
	cat_lures.text = "🪱 루어 상품 (소모 없이 무한 사용)"
	cat_lures.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cat_lures)
	
	for item in DOCK_SHOP_ITEMS["lures"]:
		_build_shop_item_row(vbox, item, "lure")
		
	vbox.add_child(HSeparator.new())
	
	# Section 2.5: Live Baits (생물 미끼)
	var cat_baits = Label.new()
	cat_baits.text = "🪱 생물 미끼 상품 (1회 구매 시 5개 획득, 소모성)"
	cat_baits.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cat_baits)
	
	for item in DOCK_SHOP_ITEMS["baits"]:
		_build_shop_item_row(vbox, item, "bait")
		
	vbox.add_child(HSeparator.new())
	
	# Section 3: Boats (보트)
	var cat_boats = Label.new()
	cat_boats.text = "⛵ 보트 상품"
	cat_boats.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cat_boats)
	
	for item in DOCK_SHOP_ITEMS["boats"]:
		_build_shop_item_row(vbox, item, "boat")

func _build_shop_item_row(parent: Control, item: Dictionary, type: String) -> void:
	var item_id = item["id"]
	var item_name = item["name"]
	var item_desc = item["desc"]
	var item_price = item["price"]
	
	var container = PanelContainer.new()
	container.add_theme_stylebox_override("panel", _create_glass_style(Color(0.08, 0.12, 0.2, 0.6), Color(0.3, 0.5, 0.8, 0.3)))
	
	var hbox = HBoxContainer.new()
	container.add_child(hbox)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var lbl_name = Label.new()
	lbl_name.text = item_name
	lbl_name.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(lbl_name)
	
	var lbl_desc = Label.new()
	lbl_desc.text = item_desc
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.self_modulate = Color(0.7, 0.85, 1.0)
	info_vbox.add_child(lbl_desc)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(110, 35)
	
	# Check if already owned
	var is_owned = false
	if type == "boat":
		is_owned = item_id in PlayerData.unlocked_boats
	elif type in ["rod", "lure"]:
		for inv_item in PlayerData.inventory:
			if inv_item["id"] == item_id:
				is_owned = true
				break
				
	if is_owned:
		btn.text = "보유 중"
		btn.disabled = true
		_style_button(btn, Color(0.1, 0.3, 0.1, 0.5))
	else:
		btn.text = "%d 쿠아" % item_price
		btn.pressed.connect(_buy_shop_item.bind(item, type))
		_style_button(btn, Color(0.6, 0.4, 0.1, 0.8))
		if PlayerData.qua < item_price:
			btn.disabled = true
			
	hbox.add_child(btn)
	parent.add_child(container)

func _buy_shop_item(item: Dictionary, type: String) -> void:
	var price = item["price"]
	if PlayerData.qua >= price:
		PlayerData.qua -= price
		
		# Add to inventory or unlocked boats
		if type == "boat":
			PlayerData.unlocked_boats.append(item["id"])
		elif type == "bait":
			var found = false
			for inv_item in PlayerData.inventory:
				if inv_item["id"] == item["id"]:
					inv_item["quantity"] = inv_item.get("quantity", 0) + 5
					found = true
					break
			if not found:
				PlayerData.inventory.append({
					"id": item["id"],
					"type": "bait",
					"name": item["name"],
					"quantity": 5
				})
		else:
			PlayerData.inventory.append({
				"id": item["id"],
				"type": type,
				"name": item["name"],
				"quantity": -1 # Reusable lure or rod
			})
			
		SaveManager.save_game()
		# Refresh the shop
		_open_dock_shop()

# ==========================================
# Large Map Information Display
# ==========================================
func _open_large_map() -> void:
	var frame = _create_popup_frame("한강 전체 지도 정보", Vector2(500, 420))
	
	# Draw larger map inside popup
	var map_panel = Panel.new()
	map_panel.position = Vector2(25, 55)
	map_panel.size = Vector2(450, 300)
	map_panel.add_theme_stylebox_override("panel", _create_glass_style(Color(0.04, 0.08, 0.15, 0.85), Color(0.3, 0.6, 0.9, 0.5)))
	frame.add_child(map_panel)
	
	# Draw active radar nodes on the map panel
	var draw_control = Control.new()
	draw_control.size = map_panel.size
	draw_control.draw.connect(func():
		var size = draw_control.size
		var center = size / 2.0
		var r = min(size.x, size.y) / 2.0 - 15.0
		
		# Grid lines
		for i in range(1, 6):
			var factor = i / 6.0
			draw_control.draw_arc(center, r * factor, 0, TAU, 32, Color(0.2, 0.5, 0.8, 0.15), 1.0)
			
		# Dock
		var du = center.x + (-5.0 / 200.0) * (r * 2.0)
		var dv = center.y + (8.0 / 200.0) * (r * 2.0)
		draw_control.draw_rect(Rect2(du - 8, dv - 10, 16, 20), Color(0.55, 0.35, 0.2, 0.9))
		
		var d_lbl = Label.new()
		d_lbl.text = "⚓ 선착장"
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.position = Vector2(du - 20, dv - 28)
		draw_control.add_child(d_lbl)
		
		# Player Boat
		var pu = center.x + (boat.global_position.x / 200.0) * (r * 2.0)
		var pv = center.y + (boat.global_position.z / 200.0) * (r * 2.0)
		draw_control.draw_circle(Vector2(pu, pv), 6.0, Color(0.9, 0.8, 0.1))
	)
	map_panel.add_child(draw_control)
	
	var footer = Label.new()
	footer.text = "원하는 곳 어디서나 낚시가 가능합니다."
	footer.add_theme_font_size_override("font_size", 12)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(25, 365)
	footer.size = Vector2(450, 30)
	frame.add_child(footer)

# ==========================================
# UI Theme Utility Functions
# ==========================================
func _create_glass_style(bg_color: Color = Color(0.05, 0.08, 0.12, 0.75), border_color: Color = Color(0.3, 0.5, 0.8, 0.4)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(10)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _style_button(btn: Button, normal_color = Color(0.1, 0.15, 0.25, 0.85)) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.set_border_width_all(1)
	normal.border_color = Color(0.25, 0.5, 0.8, 0.35)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = normal_color + Color(0.1, 0.12, 0.18)
	hover.set_border_width_all(2)
	hover.border_color = Color(0.35, 0.65, 1.0, 0.8)
	hover.set_corner_radius_all(8)
	
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = normal_color - Color(0.04, 0.04, 0.04)
	pressed.set_border_width_all(1)
	pressed.border_color = Color(0.2, 0.4, 0.7, 0.6)
	pressed.set_corner_radius_all(8)
	
	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.08, 0.08, 0.08, 0.5)
	disabled.set_border_width_all(1)
	disabled.border_color = Color(0.15, 0.15, 0.15, 0.2)
	disabled.set_corner_radius_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

func _apply_custom_theme() -> void:
	var glass_panel = _create_glass_style()
	
	# Apply glass boxes to four corners
	top_left_panel.add_theme_stylebox_override("panel", glass_panel)
	top_right_panel.add_theme_stylebox_override("panel", _create_glass_style(Color(0.05, 0.08, 0.12, 0.75), Color(0.25, 0.5, 0.85, 0.45)))
	bottom_left_panel.add_theme_stylebox_override("panel", glass_panel)
	bottom_right_panel.add_theme_stylebox_override("panel", glass_panel)
	
	# Style the boxes in fishing panel
	var gear_glass = _create_glass_style(Color(0.04, 0.08, 0.15, 0.65), Color(0.25, 0.5, 0.8, 0.25))
	$UICanvas/BottomRightPanel/VBox/FishingContainer/LureBox.add_theme_stylebox_override("panel", gear_glass)
	$UICanvas/BottomRightPanel/VBox/FishingContainer/RodBox.add_theme_stylebox_override("panel", gear_glass)
	
	# Style click button (round and red)
	var click_normal = StyleBoxFlat.new()
	click_normal.bg_color = Color(0.85, 0.15, 0.15, 0.95)
	click_normal.set_border_width_all(2)
	click_normal.border_color = Color(1.0, 0.8, 0.8, 0.4)
	click_normal.set_corner_radius_all(30)
	click_normal.content_margin_left = 6
	click_normal.content_margin_right = 6
	
	var click_hover = StyleBoxFlat.new()
	click_hover.bg_color = Color(0.95, 0.25, 0.25, 1.0)
	click_hover.set_border_width_all(3)
	click_hover.border_color = Color(1.0, 0.9, 0.9, 0.8)
	click_hover.set_corner_radius_all(30)
	
	var click_pressed = StyleBoxFlat.new()
	click_pressed.bg_color = Color(0.65, 0.1, 0.1, 0.9)
	click_pressed.set_border_width_all(2)
	click_pressed.border_color = Color(0.8, 0.6, 0.6, 0.6)
	click_pressed.set_corner_radius_all(30)
	
	var click_disabled = StyleBoxFlat.new()
	click_disabled.bg_color = Color(0.3, 0.2, 0.2, 0.5)
	click_disabled.set_border_width_all(1)
	click_disabled.border_color = Color(0.4, 0.3, 0.3, 0.2)
	click_disabled.set_corner_radius_all(30)
	
	btn_click.add_theme_stylebox_override("normal", click_normal)
	btn_click.add_theme_stylebox_override("hover", click_hover)
	btn_click.add_theme_stylebox_override("pressed", click_pressed)
	btn_click.add_theme_stylebox_override("disabled", click_disabled)
	btn_click.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	btn_click.add_theme_font_size_override("font_size", 11)
	
	# Style the cast bar
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.06, 0.1, 0.8)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0.2, 0.4, 0.7, 0.3)
	bar_bg.set_corner_radius_all(5)
	
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.6, 0.15, 0.9)
	bar_fill.set_corner_radius_all(5)
	
	cast_bar.add_theme_stylebox_override("background", bar_bg)
	cast_bar.add_theme_stylebox_override("fill", bar_fill)
	
	# Apply styles to combat fight and result boxes
	panel_fight.add_theme_stylebox_override("panel", _create_glass_style(Color(0.06, 0.09, 0.15, 0.9), Color(0.8, 0.35, 0.35, 0.5)))
	panel_result.add_theme_stylebox_override("panel", _create_glass_style(Color(0.06, 0.1, 0.16, 0.95), Color(0.2, 0.7, 0.4, 0.6)))
	
	# Style buttons
	for btn in [btn1, btn2, btn3, btn4, btn_open_map]:
		_style_button(btn)
	_style_button(btn_confirm_result, Color(0.1, 0.35, 0.15, 0.85))

func _format_number(val: int) -> String:
	var str_val = str(val)
	var formatted = ""
	var length = str_val.length()
	for i in range(length):
		if i > 0 and (length - i) % 3 == 0:
			formatted += ","
		formatted += str_val[i]
	return formatted

# ==========================================
# Casting Bar Interactions
# ==========================================
func _on_btn_click_pressed() -> void:
	if current_mode != Mode.FISHING or current_state != State.IDLE:
		return
		
	if current_cast_state == CastState.IDLE:
		current_cast_state = CastState.POWER
		cast_value = 0.0
		cast_oscillate_dir = 1.0
		cast_bar_label.text = "MIN  |  MAX"
		prompt_label.text = "캐스트바의 게이지를 결정하세요 (클릭 또는 스페이스바)"
	elif current_cast_state == CastState.POWER:
		selected_power = cast_value
		current_cast_state = CastState.DIRECTION
		cast_value = 0.5
		cast_oscillate_dir = 1.0
		cast_bar_label.text = "L  |  R"
		prompt_label.text = "캐스팅 좌우 방향을 결정하세요 (클릭 또는 스페이스바)"
	elif current_cast_state == CastState.DIRECTION:
		selected_direction = lerp(-1.0, 1.0, cast_value)
		current_cast_state = CastState.IDLE
		btn_click.disabled = true
		_start_casting_with_power(selected_power, selected_direction)

func _update_fishing_gear_labels() -> void:
	var lure_name = "초보 루어"
	var rod_name = "초보 낚싯대"
	for item in PlayerData.inventory:
		if item["id"] == PlayerData.equipped_bait:
			lure_name = item["name"]
		if item["id"] == PlayerData.equipped_rod:
			rod_name = item["name"]
	lure_label.text = "🪱 " + lure_name
	rod_label.text = "🎣 " + rod_name
