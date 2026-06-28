extends Node3D

enum State {
	IDLE,
	CASTING,
	WAITING_FOR_BITE,
	BITE,
	FIGHTING,
	CATCH_SCREEN,
	FAILED_SCREEN
}

var current_state: State = State.IDLE

# Fishing Parameters
var tension: float = 0.0
var max_tension: float = 100.0
var distance: float = 0.0
var fish_stamina: float = 100.0
var max_fish_stamina: float = 100.0

# Fish stats
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
@onready var label_prompt: Label = $UICanvas/PromptLabel
@onready var panel_fight: Panel = $UICanvas/FightPanel
@onready var progress_tension: ProgressBar = $UICanvas/FightPanel/TensionBar
@onready var progress_stamina: ProgressBar = $UICanvas/FightPanel/StaminaBar
@onready var label_distance: Label = $UICanvas/FightPanel/DistanceLabel
@onready var panel_result: Panel = $UICanvas/ResultPanel
@onready var label_result_text: Label = $UICanvas/ResultPanel/ResultText
@onready var btn_confirm_result: Button = $UICanvas/ResultPanel/ConfirmBtn

# 3D Objects
@onready var bobber: MeshInstance3D = $Bobber
@onready var camera: Camera3D = $Camera3D

# Timers
var bite_wait_time: float = 0.0
var bite_timer: float = 0.0
var reaction_timer: float = 0.0
var bobber_base_y: float = 0.0

# Fish Pool for Han River
const FISH_POOL = [
	{"name": "피라미", "min_len": 8.0, "max_len": 15.0, "weight_mult": 0.05, "base_qua": 50, "base_exp": 10, "difficulty": 1.0},
	{"name": "붕어", "min_len": 15.0, "max_len": 35.0, "weight_mult": 0.15, "base_qua": 100, "base_exp": 25, "difficulty": 1.5},
	{"name": "잉어", "min_len": 35.0, "max_len": 70.0, "weight_mult": 0.4, "base_qua": 250, "base_exp": 50, "difficulty": 2.2},
	{"name": "메기", "min_len": 40.0, "max_len": 80.0, "weight_mult": 0.5, "base_qua": 400, "base_exp": 80, "difficulty": 3.0},
	{"name": "가물치", "min_len": 55.0, "max_len": 95.0, "weight_mult": 0.7, "base_qua": 600, "base_exp": 120, "difficulty": 4.2}
]

func _ready() -> void:
	panel_fight.visible = false
	panel_result.visible = false
	label_prompt.text = "마우스 클릭으로 찌를 캐스팅하세요."
	
	if bobber:
		bobber_base_y = bobber.global_position.y
		bobber.visible = false
		
	btn_confirm_result.pressed.connect(_on_confirm_result_pressed)
	$UICanvas/BackBtn.pressed.connect(_on_back_pressed)

func _process(delta: float) -> void:
	match current_state:
		State.IDLE:
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_start_casting()
				
		State.CASTING:
			# Simulate bobber flying in air
			reaction_timer += delta
			var progress = reaction_timer / 1.5
			if progress >= 1.0:
				_enter_wait_bite()
			else:
				# Simple parabolic trajectory
				var t = progress
				bobber.global_position = Vector3(
					lerp(0.0, 0.0, t),
					bobber_base_y + sin(t * PI) * 2.0,
					lerp(0.0, -8.0, t)
				)
				
		State.WAITING_FOR_BITE:
			bite_timer += delta
			# Idle bobber bobbing in water
			bobber.global_position.y = bobber_base_y + sin(Time.get_ticks_msec() * 0.005) * 0.05
			if bite_timer >= bite_wait_time:
				_enter_bite()
				
		State.BITE:
			reaction_timer += delta
			# Bobber sinks rapidly
			bobber.global_position.y = bobber_base_y - 0.6 + sin(Time.get_ticks_msec() * 0.02) * 0.05
			
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				# Clicked in time!
				_start_fighting()
			elif reaction_timer >= 1.2: # 1.2 seconds reaction limit
				_fail_fishing("물고기가 미끼를 먹고 도망쳤습니다.")

		State.FIGHTING:
			_process_fighting(delta)

func _start_casting() -> void:
	current_state = State.CASTING
	reaction_timer = 0.0
	bobber.visible = true
	bobber.global_position = Vector3(0, bobber_base_y, 0)
	label_prompt.text = "캐스팅 중..."

func _enter_wait_bite() -> void:
	current_state = State.WAITING_FOR_BITE
	bite_timer = 0.0
	# Wait between 3 to 7 seconds
	bite_wait_time = randf_range(3.0, 7.0)
	label_prompt.text = "찌가 수면에 내려앉았습니다. 입질을 기다리는 중..."

func _enter_bite() -> void:
	current_state = State.BITE
	reaction_timer = 0.0
	label_prompt.text = "!!! 입질이 왔습니다 !!! 즉시 마우스 클릭!"

func _start_fighting() -> void:
	current_state = State.FIGHTING
	label_prompt.text = "파이트 시작! 장력을 유지하며 당기세요!"
	panel_fight.visible = true
	
	# Select random fish from pool
	var fish_template = FISH_POOL.pick_random()
	active_fish_name = fish_template["name"]
	active_fish_length = randf_range(fish_template["min_len"], fish_template["max_len"])
	active_fish_weight = active_fish_length * fish_template["weight_mult"] * randf_range(0.9, 1.1)
	
	# Level scale rewards
	active_fish_reward = int(fish_template["base_qua"] * randf_range(0.9, 1.2))
	active_fish_exp = int(fish_template["base_exp"] * randf_range(0.9, 1.1))
	
	# Fight params
	var diff = fish_template["difficulty"]
	distance = randf_range(30.0, 60.0) * diff
	max_fish_stamina = 100.0 * diff
	fish_stamina = max_fish_stamina
	tension = 20.0
	is_fish_angry = false
	fish_angry_timer = randf_range(2.0, 5.0)
	fish_pull_force = 10.0 * diff

func _process_fighting(delta: float) -> void:
	# Check click for reeling
	var is_reeling = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	
	# Fish anger state machine
	fish_angry_timer -= delta
	if fish_angry_timer <= 0.0:
		is_fish_angry = !is_fish_angry
		if is_fish_angry:
			fish_angry_timer = randf_range(1.5, 3.0) # Angry dur
			label_prompt.text = "경고: 물고기가 격렬하게 날뜁니다! 텐션 주의!"
		else:
			fish_angry_timer = randf_range(3.0, 6.0) # Calm dur
			label_prompt.text = "물고기가 다소 진정되었습니다. 감아 올리세요!"
			
	# Math formulas
	var current_pull = fish_pull_force
	if is_fish_angry:
		current_pull *= 2.0 # double force
		
	# Tension delta
	var tension_change = 0.0
	if is_reeling:
		# Reel in increases tension
		tension_change += 25.0
		# Pulling back increases tension
		tension_change += current_pull
		# Reel decreases distance
		distance -= 5.0 * delta
		# Tire the fish
		fish_stamina -= 8.0 * delta
	else:
		# Release decreases tension
		tension_change -= 30.0
		# Fish pulls line out
		distance += (current_pull * 0.2) * delta
		# Tension from fish pull remains slightly
		tension_change += current_pull * 0.5
		# Fish recovers some stamina
		fish_stamina += 2.0 * delta
		fish_stamina = clamp(fish_stamina, 0.0, max_fish_stamina)
		
	# Constant line friction drop
	tension += tension_change * delta
	tension = clamp(tension, 0.0, max_tension)
	
	# Limit distance
	distance = clamp(distance, 0.0, 200.0)
	
	# Update UI
	progress_tension.value = tension
	progress_stamina.value = (fish_stamina / max_fish_stamina) * 100.0
	label_distance.text = "거리: %.1f m" % distance
	
	# Color tension bar (red alert)
	if tension >= 80.0:
		progress_tension.self_modulate = Color(1.0, 0.2, 0.2)
	else:
		progress_tension.self_modulate = Color(1.0, 1.0, 1.0)
		
	# Bobber visual follows distance
	bobber.global_position.z = -distance * 0.2
	
	# Check Win/Loss conditions
	if distance <= 0.0:
		_success_fishing()
	elif tension >= max_tension:
		_fail_fishing("장력이 임계점을 넘어 낚싯줄이 끊어졌습니다! (Line Snap)")
	elif distance >= 120.0:
		_fail_fishing("물고기가 줄을 끊지 않고 멀리 도망쳐 놓쳤습니다! (Escape)")

func _success_fishing() -> void:
	current_state = State.CATCH_SCREEN
	panel_fight.visible = false
	bobber.visible = false
	
	# Apply rewards
	PlayerData.qua += active_fish_reward
	PlayerData.exp += active_fish_exp
	
	# Add to inventory/aquarium stats if needed
	var catch_record = {
		"name": active_fish_name,
		"length": snapped(active_fish_length, 0.1),
		"weight": snapped(active_fish_weight, 0.1),
		"date": Time.get_date_string_from_system()
	}
	PlayerData.aquarium_fish.append(catch_record)
	
	# Save changes
	SaveManager.save_game()
	
	# Show UI
	label_result_text.text = "[포획 성공!]\n\n어종: %s\n길이: %.1f cm\n무게: %.1f kg\n\n획득 재화: +%d 쿠아\n획득 경험치: +%d EXP" % [
		active_fish_name, active_fish_length, active_fish_weight, active_fish_reward, active_fish_exp
	]
	panel_result.visible = true

func _fail_fishing(reason: String) -> void:
	current_state = State.FAILED_SCREEN
	panel_fight.visible = false
	bobber.visible = false
	
	label_result_text.text = "[포획 실패]\n\n이유: %s" % reason
	panel_result.visible = true

func _on_confirm_result_pressed() -> void:
	panel_result.visible = false
	current_state = State.IDLE
	label_prompt.text = "마우스 클릭으로 다시 찌를 캐스팅하세요."

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MapSelection.tscn")
