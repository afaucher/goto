## Enemy entity for GOTO.
## Has a repeating instruction pattern that loops forever.
class_name Enemy
extends Node3D

signal destroyed(enemy: Enemy)

var hp: int = 3
var grid_pos: Vector2i = Vector2i.ZERO
var facing: Robot.Direction = Robot.Direction.NORTH
var is_alive: bool = true
var is_disabled: bool = false  # EMP'd

## Repeating instruction pattern (array of Instruction.Type)
var pattern: Array = []
var pattern_index: int = 0

var _body_mesh: MeshInstance3D
var _eye_mesh: MeshInstance3D


func _ready() -> void:
	_build_visuals()


func _build_visuals() -> void:
	_body_mesh = MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.65, 0.65, 0.65)
	_body_mesh.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.8, 0.15, 0.15)
	body_mat.roughness = 0.4
	body_mat.metallic = 0.3
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.325, 0)
	add_child(_body_mesh)

	# Single red eye (menacing)
	_eye_mesh = MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.1
	eye_sphere.height = 0.2
	_eye_mesh.mesh = eye_sphere
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.0, 0.0)
	eye_mat.emission_energy_multiplier = 1.5
	_eye_mesh.material_override = eye_mat
	_body_mesh.add_child(_eye_mesh)
	_update_eye_position()


func _update_eye_position() -> void:
	var forward := _direction_to_vector3(facing)
	_eye_mesh.position = forward * 0.34 + Vector3(0, 0.05, 0)


## Get the next instruction type from the repeating pattern.
func get_next_instruction_type() -> Instruction.Type:
	if pattern.is_empty():
		return Instruction.Type.WAIT
	if is_disabled:
		is_disabled = false
		return Instruction.Type.WAIT
	var instr_type: Instruction.Type = pattern[pattern_index]
	pattern_index = (pattern_index + 1) % pattern.size()
	return instr_type


## Take damage.
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		is_alive = false
		destroyed.emit(self)
		visible = false


## Set facing direction.
func set_facing(dir: Robot.Direction) -> void:
	facing = dir
	_update_eye_position()
	_body_mesh.rotation.y = _direction_to_angle(dir)


func _direction_to_vector3(dir: Robot.Direction) -> Vector3:
	match dir:
		Robot.Direction.NORTH: return Vector3(0, 0, -1)
		Robot.Direction.EAST: return Vector3(1, 0, 0)
		Robot.Direction.SOUTH: return Vector3(0, 0, 1)
		Robot.Direction.WEST: return Vector3(-1, 0, 0)
	return Vector3.ZERO


func _direction_to_angle(dir: Robot.Direction) -> float:
	match dir:
		Robot.Direction.NORTH: return 0.0
		Robot.Direction.EAST: return -PI / 2.0
		Robot.Direction.SOUTH: return PI
		Robot.Direction.WEST: return PI / 2.0
	return 0.0
