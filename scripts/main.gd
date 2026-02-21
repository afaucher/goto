## Main scene script for GOTO.
## Wires together level generation, rendering, camera, HUD, and game flow.
extends Node3D

var _level_renderer: Node3D
var _camera: Camera3D
var _hud: CanvasLayer
var _fog: Node3D
var _light: DirectionalLight3D


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

	# Create HUD
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.set_script(load("res://scripts/hud.gd"))
	add_child(_hud)

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

	# Center camera on level
	var center_x: float = GameManager.level.width * 0.5
	var center_z: float = GameManager.level.height * 0.5
	_camera.center_on(Vector3(center_x, 0, center_z))


func _process(_delta: float) -> void:
	# Update fog of war each frame (or could be per-turn)
	if GameManager.current_state == GameManager.GameState.EXECUTING:
		_fog.update_visibility()
		_fog.apply_visibility(_level_renderer, GameManager.enemies)

	# Quit
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()
