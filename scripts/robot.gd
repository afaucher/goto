## Robot entity for GOTO.
## Manages instruction buffer, health, facing, and grid position.
class_name Robot
extends Node3D

signal destroyed(robot: Robot)
signal instruction_executed(robot: Robot, instruction: Instruction)

enum Direction { NORTH, EAST, SOUTH, WEST }

const MAX_HP: int = 5
const ROBOT_COLORS: Array[Color] = [
	Color(0.2, 0.6, 1.0),   # Blue
	Color(1.0, 0.3, 0.3),   # Red
	Color(0.3, 0.9, 0.3),   # Green
	Color(1.0, 0.7, 0.1),   # Gold
]

@export var robot_id: int = 0

var hp: int = MAX_HP
var grid_pos: Vector2i = Vector2i.ZERO
var facing: Direction = Direction.NORTH
var instruction_buffer: Array = []  # Array of Instruction or null
var has_shield: bool = false
var is_alive: bool = true
var controlled_by: Array[int] = []  # Player peer IDs

# Visual components
var _body_mesh: MeshInstance3D
var _eye_left: MeshInstance3D
var _eye_right: MeshInstance3D
var _shield_mesh: MeshInstance3D


func _ready() -> void:
	_build_visuals()
	_init_buffer()


func _build_visuals() -> void:
	# Body: cube
	_body_mesh = MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.7, 0.7, 0.7)
	_body_mesh.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	var color_idx: int = clampi(robot_id, 0, ROBOT_COLORS.size() - 1)
	body_mat.albedo_color = ROBOT_COLORS[color_idx]
	body_mat.roughness = 0.3
	body_mat.metallic = 0.2
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.35, 0)
	add_child(_body_mesh)

	# Eyes: two small white spheres on the front face
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.08
	eye_mesh.height = 0.16
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.WHITE
	eye_mat.emission_enabled = true
	eye_mat.emission = Color.WHITE
	eye_mat.emission_energy_multiplier = 0.8

	_eye_left = MeshInstance3D.new()
	_eye_left.mesh = eye_mesh
	_eye_left.material_override = eye_mat
	_body_mesh.add_child(_eye_left)

	_eye_right = MeshInstance3D.new()
	_eye_right.mesh = eye_mesh
	_eye_right.material_override = eye_mat
	_body_mesh.add_child(_eye_right)

	_update_eye_positions()

	# Shield visual (hidden by default)
	_shield_mesh = MeshInstance3D.new()
	var shield_sphere := SphereMesh.new()
	shield_sphere.radius = 0.55
	shield_sphere.height = 1.1
	_shield_mesh.mesh = shield_sphere
	var shield_mat := StandardMaterial3D.new()
	shield_mat.albedo_color = Color(0.2, 0.5, 1.0, 0.3)
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emission_enabled = true
	shield_mat.emission = Color(0.2, 0.5, 1.0)
	shield_mat.emission_energy_multiplier = 0.3
	_shield_mesh.material_override = shield_mat
	_shield_mesh.position = Vector3(0, 0.35, 0)
	_shield_mesh.visible = false
	add_child(_shield_mesh)


func _update_eye_positions() -> void:
	# Eyes always face the robot's direction
	var forward: Vector3 = _direction_to_vector3(facing)
	var right: Vector3 = forward.cross(Vector3.UP)
	_eye_left.position = forward * 0.36 + right * 0.12 + Vector3(0, 0.1, 0)
	_eye_right.position = forward * 0.36 - right * 0.12 + Vector3(0, 0.1, 0)


func _init_buffer() -> void:
	instruction_buffer.clear()
	for _i: int in range(hp):
		instruction_buffer.append(null)


## Get the buffer capacity (equals current HP)
func get_buffer_size() -> int:
	return hp


## Add an instruction to the first empty slot. Returns true if successful.
func add_instruction(instr: Instruction) -> bool:
	for i: int in range(instruction_buffer.size()):
		if instruction_buffer[i] == null:
			instruction_buffer[i] = instr
			return true
	return false


## Remove instruction from a specific slot and return it.
func remove_instruction(idx: int) -> Instruction:
	if idx < 0 or idx >= instruction_buffer.size():
		return null
	var instr: Instruction = instruction_buffer[idx]
	instruction_buffer[idx] = null
	return instr


## Get the next instruction to execute (first non-null).
func pop_next_instruction() -> Instruction:
	for i: int in range(instruction_buffer.size()):
		if instruction_buffer[i] != null:
			var instr: Instruction = instruction_buffer[i]
			instruction_buffer[i] = null
			return instr
	return null


## Take damage. Reduces HP, shrinks buffer, destroys instructions.
func take_damage(amount: int) -> void:
	if has_shield:
		has_shield = false
		_shield_mesh.visible = false
		return

	for _i: int in range(amount):
		if hp <= 0:
			break
		hp -= 1
		# Destroy the last instruction if buffer has one
		if instruction_buffer.size() > hp:
			instruction_buffer.resize(hp)

	if hp <= 0:
		is_alive = false
		destroyed.emit(self)
		visible = false


## Set facing direction and update visuals.
func set_facing(dir: Direction) -> void:
	facing = dir
	_update_eye_positions()
	# Rotate body to match facing
	var angle: float = _direction_to_angle(dir)
	_body_mesh.rotation.y = angle


## Activate shield visual.
func activate_shield() -> void:
	has_shield = true
	_shield_mesh.visible = true


## Heal HP (up to MAX_HP).
func heal(amount: int) -> void:
	var old_hp: int = hp
	hp = mini(hp + amount, MAX_HP)
	# Extend buffer if HP increased
	while instruction_buffer.size() < hp:
		instruction_buffer.append(null)


## Get the forward direction as a Vector2i (grid coordinates).
static func direction_to_vec(dir: Direction) -> Vector2i:
	match dir:
		Direction.NORTH: return Vector2i(0, -1)
		Direction.EAST: return Vector2i(1, 0)
		Direction.SOUTH: return Vector2i(0, 1)
		Direction.WEST: return Vector2i(-1, 0)
	return Vector2i.ZERO


## Get the left-rotated direction.
static func turn_left_dir(dir: Direction) -> Direction:
	return (dir + 3) % 4 as Direction


## Get the right-rotated direction.
static func turn_right_dir(dir: Direction) -> Direction:
	return (dir + 1) % 4 as Direction


## Get the opposite direction.
static func reverse_dir(dir: Direction) -> Direction:
	return (dir + 2) % 4 as Direction


func _direction_to_vector3(dir: Direction) -> Vector3:
	match dir:
		Direction.NORTH: return Vector3(0, 0, -1)
		Direction.EAST: return Vector3(1, 0, 0)
		Direction.SOUTH: return Vector3(0, 0, 1)
		Direction.WEST: return Vector3(-1, 0, 0)
	return Vector3.ZERO


func _direction_to_angle(dir: Direction) -> float:
	match dir:
		Direction.NORTH: return 0.0
		Direction.EAST: return -PI / 2.0
		Direction.SOUTH: return PI
		Direction.WEST: return PI / 2.0
	return 0.0
