## Renders the voxel level as isometric 3D cubes.
## Attach to a Node3D in the main scene.
extends Node3D

const TILE_SIZE: float = 1.0
const WALL_HEIGHT: float = 1.0

var _floor_mesh: BoxMesh
var _wall_mesh: BoxMesh

# Materials
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _gap_material: StandardMaterial3D
var _exit_material: StandardMaterial3D
var _key_material: StandardMaterial3D
var _door_material: StandardMaterial3D

# Multimesh instances for performance
var _floor_multimesh_instance: MultiMeshInstance3D
var _wall_multimesh_instance: MultiMeshInstance3D
var _special_tiles: Array[MeshInstance3D] = []

var _level: LevelGenerator


func _ready() -> void:
	_create_materials()
	_create_meshes()


func _create_materials() -> void:
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color(0.75, 0.78, 0.82)
	_floor_material.roughness = 0.8

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.35, 0.38, 0.45)
	_wall_material.roughness = 0.6

	_gap_material = StandardMaterial3D.new()
	_gap_material.albedo_color = Color(0.08, 0.05, 0.12)
	_gap_material.roughness = 1.0

	_exit_material = StandardMaterial3D.new()
	_exit_material.albedo_color = Color(0.1, 0.9, 0.3)
	_exit_material.emission_enabled = true
	_exit_material.emission = Color(0.1, 0.9, 0.3)
	_exit_material.emission_energy_multiplier = 0.8

	_key_material = StandardMaterial3D.new()
	_key_material.albedo_color = Color(1.0, 0.85, 0.0)
	_key_material.emission_enabled = true
	_key_material.emission = Color(1.0, 0.85, 0.0)
	_key_material.emission_energy_multiplier = 0.8

	_door_material = StandardMaterial3D.new()
	_door_material.albedo_color = Color(0.6, 0.3, 0.1)
	_door_material.roughness = 0.4


func _create_meshes() -> void:
	_floor_mesh = BoxMesh.new()
	_floor_mesh.size = Vector3(TILE_SIZE * 0.95, TILE_SIZE * 0.2, TILE_SIZE * 0.95)

	_wall_mesh = BoxMesh.new()
	_wall_mesh.size = Vector3(TILE_SIZE * 0.95, WALL_HEIGHT, TILE_SIZE * 0.95)


func build_level(level: LevelGenerator) -> void:
	_level = level
	_clear_existing()

	# Count tiles for multimesh
	var floor_count: int = 0
	var wall_count: int = 0
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.floor_grid[y][x] == LevelGenerator.FloorCell.SOLID:
				floor_count += 1
			if level.wall_grid[y][x] == LevelGenerator.WallCell.WALL:
				wall_count += 1

	# Build floor multimesh (includes tiles under walls)
	_build_floor_multimesh(level, floor_count)
	# Build wall multimesh
	_build_wall_multimesh(level, wall_count)
	# Build special tiles (exit, key, door) as individual meshes
	_build_special_tiles(level)
	# Build gap indicators
	_build_gap_tiles(level)


func _clear_existing() -> void:
	for child: Node in get_children():
		child.queue_free()
	_special_tiles.clear()


func _build_floor_multimesh(level: LevelGenerator, count: int) -> void:
	if count == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _floor_mesh
	mm.instance_count = count

	var idx: int = 0
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.floor_grid[y][x] == LevelGenerator.FloorCell.SOLID:
				# Floor sits at Y=0 (centered at -0.1 so top is at 0.0)
				var pos := Vector3(x * TILE_SIZE, -0.1, y * TILE_SIZE)
				var t := Transform3D()
				t.origin = pos
				mm.set_instance_transform(idx, t)
				idx += 1

	mm.instance_count = idx
	_floor_multimesh_instance = MultiMeshInstance3D.new()
	_floor_multimesh_instance.multimesh = mm
	_floor_multimesh_instance.material_override = _floor_material
	add_child(_floor_multimesh_instance)


func _build_wall_multimesh(level: LevelGenerator, count: int) -> void:
	if count == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _wall_mesh
	mm.instance_count = count

	var idx: int = 0
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.wall_grid[y][x] == LevelGenerator.WallCell.WALL:
				# Wall sits on top of floor: base at Y=0, center at WALL_HEIGHT/2
				var pos := Vector3(x * TILE_SIZE, WALL_HEIGHT * 0.5, y * TILE_SIZE)
				var t := Transform3D()
				t.origin = pos
				mm.set_instance_transform(idx, t)
				idx += 1

	_wall_multimesh_instance = MultiMeshInstance3D.new()
	_wall_multimesh_instance.multimesh = mm
	_wall_multimesh_instance.material_override = _wall_material
	add_child(_wall_multimesh_instance)


func _build_special_tiles(level: LevelGenerator) -> void:
	# Exit - glowing green pad on the floor
	_add_special_tile(level.exit_position, _exit_material, 0.25)

	# Keys - glowing gold marker
	for key_pos: Vector2i in level.key_positions:
		_add_special_tile(key_pos, _key_material, 0.35)

	# Doors - tall brown blocks
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.wall_grid[y][x] == LevelGenerator.WallCell.DOOR_LOCKED:
				_add_special_tile(Vector2i(x, y), _door_material, WALL_HEIGHT * 0.8)


func _add_special_tile(grid_pos: Vector2i, mat: StandardMaterial3D, height: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TILE_SIZE * 0.9, height, TILE_SIZE * 0.9)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	# Position: sits on top of floor (base at Y=0)
	mesh_inst.position = Vector3(grid_pos.x * TILE_SIZE, height * 0.5, grid_pos.y * TILE_SIZE)
	add_child(mesh_inst)
	_special_tiles.append(mesh_inst)


func _build_gap_tiles(level: LevelGenerator) -> void:
	# Render thin dark planes at floor level where gaps are
	for y: int in range(level.height):
		for x: int in range(level.width):
			if level.floor_grid[y][x] == LevelGenerator.FloorCell.GAP:
				var mesh_inst := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(TILE_SIZE * 0.95, 0.05, TILE_SIZE * 0.95)
				mesh_inst.mesh = box
				mesh_inst.material_override = _gap_material
				# Gaps at same level as floor surface (Y = -0.1)
				mesh_inst.position = Vector3(x * TILE_SIZE, -0.1, y * TILE_SIZE)
				add_child(mesh_inst)


## Convert grid position to world position (entity standing height).
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * TILE_SIZE, 0.0, grid_pos.y * TILE_SIZE)
