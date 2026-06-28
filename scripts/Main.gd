extends Control

@onready var btn_single: Button = $VBoxContainer/BtnSingle
@onready var btn_multi: Button = $VBoxContainer/BtnMulti
@onready var btn_exit: Button = $VBoxContainer/BtnExit

func _ready() -> void:
	# 시작 시 데이터 불러오기
	SaveManager.load_game()
	
	btn_single.pressed.connect(_on_single_pressed)
	btn_multi.pressed.connect(_on_multi_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)

func _on_single_pressed() -> void:
	SaveManager.is_multiplayer = false
	print("싱글플레이 시작: ", PlayerData.nickname, " (Level ", PlayerData.level, ")")
	get_tree().change_scene_to_file("res://scenes/WorldMapSelection.tscn")

func _on_multi_pressed() -> void:
	SaveManager.is_multiplayer = true
	print("멀티플레이 시도 (서버 연동 개발 예정)")
	get_tree().change_scene_to_file("res://scenes/WorldMapSelection.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
