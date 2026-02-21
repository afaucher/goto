## Main scene script for GOTO.
## Wires together level generation, rendering, camera, HUD, and game flow.
extends Node3D

var _level_renderer: Node3D
var _camera: Camera3D
var _hud: HUD
var _fog: Node3D
var _vfx: Node3D
var _light: DirectionalLight3D

var _selected_robot_id: int = 0


func _ready() -> void:
	# Create lighting
	_setup_lighting()

	# Create level renderer
	_level_renderer = Node3D.new()
	_level_renderer.name = "LevelRenderer"
	_level_renderer.set_script(load("res://scripts/level_renderer.gd"))
	add_child(_level_renderer)

	# Create camera
	_camera = Camera3D.new()
	_camera.name = "IsometricCamera"
	_camera.set_script(load("res://scripts/camera_controller.gd"))
	add_child(_camera)

	# Create fog of war
	_fog = Node3D.new()
	_fog.name = "FogOfWar"
	_fog.set_script(load("res://scripts/fog_of_war.gd"))
	add_child(_fog)

	# Create VFX manager
	_vfx = Node3D.new()
	_vfx.name = "VFXManager"
	_vfx.set_script(load("res://scripts/vfx_manager.gd"))
	add_child(_vfx)

	# Create HUD
	_hud = HUD.new()
	_hud.name = "HUD"
	add_child(_hud)

	# Connect HUD signals
	_hud.selected_robot_changed.connect(_on_robot_selected)

	# Initialize game
	_initialize_game()


func _setup_lighting() -> void:
	# Main directional light for isometric shading
	_light = DirectionalLight3D.new()
	_light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	_light.shadow_enabled = true
	_light.light_energy = 1.2
	_light.light_color = Color(1.0, 0.98, 0.95)
	add_child(_light)

	# Ambient fill
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.4)
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)


func _initialize_game() -> void:
	# Initialize GameManager (autoload) with references
	GameManager.initialize(self, _level_renderer)

	# Build the level visuals
	_level_renderer.build_level(GameManager.level)

	# Setup fog of war
	_fog.setup(GameManager.level, GameManager.robots)
	_fog.update_visibility()
	_fog.apply_visibility(_level_renderer, GameManager.enemies)

	# Setup VFX
	_vfx.setup(_level_renderer)
	GameManager.turn_engine.vfx_requested.connect(_on_vfx_requested)

	# Center camera on first robot
	if not GameManager.robots.is_empty():
		var robot: Robot = GameManager.robots[0]
		_camera.center_on(_level_renderer.grid_to_world(robot.grid_pos))


func _on_robot_selected(robot_id: int) -> void:
	_selected_robot_id = robot_id
	# Camera will smoothly pan via follow_target in _process


func _process(delta: float) -> void:
	if GameManager == null:
		return
	# Camera follows selected robot smoothly
	if _selected_robot_id < GameManager.robots.size():
		var robot: Robot = GameManager.robots[_selected_robot_id]
		if robot.is_alive:
			_camera.follow_target(_level_renderer.grid_to_world(robot.grid_pos), delta)

	# Update fog of war during execution
	if GameManager.current_state == GameManager.GameState.EXECUTING:
		_fog.update_visibility()
		_fog.apply_visibility(_level_renderer, GameManager.enemies)

	# Quit
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()


func _on_vfx_requested(effect_name: String, data: Dictionary) -> void:
	match effect_name:
		"laser":
			_vfx.show_laser(data["start"], data["dir"], data["end"])
		"shotgun":
			_vfx.show_shotgun(data["pos"], data["dir"])
		"damage":
			_vfx.show_damage_flash(data["pos"])
		"shove":
			_vfx.show_shove(data["pos"], data["dir"])
		"explosion":
			_vfx.show_explosion(data["pos"])
		"emp":
			_vfx.show_emp(data["pos"])
		"teleport":
			_vfx.show_teleport(data["pos"])
		"shield":
			_vfx.show_shield_activate(data["pos"])
