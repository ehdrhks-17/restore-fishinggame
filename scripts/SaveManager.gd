extends Node

const SAVE_FILE_PATH = "user://save_single.json"

# Mode configuration (true when transitioning to multiplayer)
var is_multiplayer: bool = false
var server_api_url: String = "http://localhost:3000/api/save"

# Save game state
func save_game() -> void:
	var data = PlayerData.to_dict()
	if is_multiplayer:
		_save_to_server(data)
	else:
		_save_to_local(data)

# Load game state
func load_game() -> void:
	if is_multiplayer:
		await _load_from_server()
	else:
		_load_from_local()

# Local implementation (JSON-based)
func _save_to_local(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
		print("로컬 저장 성공: ", SAVE_FILE_PATH)
	else:
		print("에러: 로컬 저장 파일을 열 수 없습니다.")

func _load_from_local() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("알림: 저장 파일이 없어 기본 데이터로 시작합니다.")
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				PlayerData.from_dict(data)
				print("로컬 데이터 로드 성공.")
			else:
				print("에러: 데이터 구조가 올바르지 않습니다.")
		else:
			print("JSON 파싱 에러: ", json.get_error_message())
	else:
		print("에러: 로컬 저장 파일을 읽을 수 없습니다.")

# Server-authoritative placeholders (for future multiplayer migration)
func _save_to_server(_data: Dictionary) -> void:
	# TODO: Implement HTTPRequest node or WebSocket packet transfer
	print("[멀티] 서버 저장 요청 (미구현)")

func _load_from_server() -> void:
	# TODO: Implement HTTPRequest node or WebSocket packet transfer
	print("[멀티] 서버 로드 요청 (미구현)")
