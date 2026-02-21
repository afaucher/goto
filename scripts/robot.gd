## Robot entity for GOTO.
## Manages instruction buffer, health, facing, and grid position.
## Visually distinct: colored cube body with two white eyes and floating label.
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
var _label: Label3D
var _antenna: MeshInstance3D
var _arrow: MeshInstance3D


func _ready() -> void:
	_build_visuals()
	_init_buffer()
	# Apply initial facing (may be set before add_child)
	set_facing(facing)


func _build_visuals() -> void:
	var color_idx: int = clampi(robot_id, 0, ROBOT_COLORS.size() - 1)
	var robot_color: Color = ROBOT_COLORS[color_idx]

	# Body: rounded-ish cube (slightly taller)
	_body_mesh = MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.7, 0.8, 0.7)
	_body_mesh.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = robot_color
	body_mat.roughness = 0.3
	body_mat.metallic = 0.2
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.4, 0)
	add_child(_body_mesh)

	# Antenna on top (distinguishes from enemies)
	_antenna = MeshInstance3D.new()
	var ant_mesh := CylinderMesh.new()
	ant_mesh.top_radius = 0.03
	ant_mesh.bottom_radius = 0.03
	ant_mesh.height = 0.3
	_antenna.mesh = ant_mesh
	var ant_mat := StandardMaterial3D.new()
	ant_mat.albedo_color = robot_color * 1.3
	ant_mat.emission_enabled = true
	ant_mat.emission = robot_color
	ant_mat.emission_energy_multiplier = 0.5
	_antenna.material_override = ant_mat
	_antenna.position = Vector3(0, 0.55, 0)
	_body_mesh.add_child(_antenna)

	# Antenna tip (glowing ball)
	var tip := MeshInstance3D.new()
	var tip_sphere := SphereMesh.new()
	tip_sphere.radius = 0.06
	tip_sphere.height = 0.12
	tip.mesh = tip_sphere
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color.WHITE
	tip_mat.emission_enabled = true
	tip_mat.emission = robot_color
	tip_mat.emission_energy_multiplier = 1.5
	tip.material_override = tip_mat
	tip.position = Vector3(0, 0.15, 0)
	_antenna.add_child(tip)

	# Eyes: two white spheres on the front face
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.09
	eye_mesh.height = 0.18
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

	# Pupil dots (black centers)
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.04
	pupil_mesh.height = 0.08
	var pupil_mat := StandardMaterial3D.new()
	pupil_mat.albedo_color = Color(0.05, 0.05, 0.1)

	var pupil_l := MeshInstance3D.new()
	pupil_l.mesh = pupil_mesh
	pupil_l.material_override = pupil_mat
	pupil_l.position = Vector3(0, 0, 0.05)
	_eye_left.add_child(pupil_l)

	var pupil_r := MeshInstance3D.new()
	pupil_r.mesh = pupil_mesh
	pupil_r.material_override = pupil_mat
	pupil_r.position = Vector3(0, 0, 0.05)
	_eye_right.add_child(pupil_r)

	_update_eye_positions()

	# Directional arrow on top of body (cone pointing forward)
	_arrow = MeshInstance3D.new()
	var arrow_cone := CylinderMesh.new()
	arrow_cone.top_radius = 0.0
	arrow_cone.bottom_radius = 0.15
	arrow_cone.height = 0.3
	_arrow.mesh = arrow_cone
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = robot_color
	arrow_mat.emission_enabled = true
	arrow_mat.emission = robot_color
	arrow_mat.emission_energy_multiplier = 1.0
	_arrow.material_override = arrow_mat
	# Position on top of body, rotated to point forward (cone tip = +Y, so rotate -90 on X to point +Z)
	_arrow.position = Vector3(0, 0.45, 0)
	_arrow.rotation = Vector3(deg_to_rad(-90), 0, 0)
	_body_mesh.add_child(_arrow)
	_update_arrow_rotation()

	# Floating label above robot
	_label = Label3D.new()
	_label.text = "R%d" % (robot_id + 1)
	_label.font_size = 48
	_label.modulate = robot_color
	_label.outline_modulate = Color.BLACK
	_label.outline_size = 8
	_label.position = Vector3(0, 1.2, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

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
	_shield_mesh.position = Vector3(0, 0.4, 0)
	_shield_mesh.visible = false
	add_child(_shield_mesh)


func _update_eye_positions() -> void:
	# Eyes always face the robot's direction
	var forward: Vector3 = _direction_to_vector3(facing)
	var right: Vector3 = forward.cross(Vector3.UP)
	_eye_left.position = forward * 0.36 + right * 0.14 + Vector3(0, 0.1, 0)
	_eye_right.position = forward * 0.36 - right * 0.14 + Vector3(0, 0.1, 0)


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
	_update_arrow_rotation()
	# Rotate body to match facing
	var angle: float = _direction_to_angle(dir)
	_body_mesh.rotation.y = angle


## Update arrow cone to point in facing direction.
## Arrow is a child of body_mesh, so we position it relative to body.
## The cone's tip points along local +Y, rotated -90 on X makes it point +Z.
## We then rotate it around Y to match the facing direction.
func _update_arrow_rotation() -> void:
	if _arrow == null:
		return
	var forward: Vector3 = _direction_to_vector3(facing)
	# Place arrow slightly in front of body top, pointing outward
	_arrow.position = forward * 0.25 + Vector3(0, 0.45, 0)
	# Cone tip (+Y) needs to point in facing direction
	# Base rotation: -90 on X makes tip point +Z (south/default)
	# Then rotate Y to match direction
	match facing:
		Direction.NORTH:
			_arrow.rotation = Vector3(deg_to_rad(-90), 0, 0)
		Direction.EAST:
			_arrow.rotation = Vector3(0, 0, deg_to_rad(-90))
		Direction.SOUTH:
			_arrow.rotation = Vector3(deg_to_rad(90), 0, 0)
		Direction.WEST:
			_arrow.rotation = Vector3(0, 0, deg_to_rad(90))


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
