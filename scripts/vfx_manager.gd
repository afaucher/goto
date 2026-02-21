## Visual effects manager for GOTO.
## Creates temporary visual indicators for actions and combat.
extends Node3D

var _level_renderer: Node3D


func setup(renderer: Node3D) -> void:
	_level_renderer = renderer


## Show a laser beam from one grid position in a direction.
func show_laser(start_pos: Vector2i, direction: Vector2i, hits_at: Vector2i) -> void:
	if _level_renderer == null:
		return
	var from_world: Vector3 = _level_renderer.grid_to_world(start_pos) + Vector3(0, 0.5, 0)
	var to_world: Vector3 = _level_renderer.grid_to_world(hits_at) + Vector3(0, 0.5, 0)

	# Create a cylinder beam between the two points
	var beam := MeshInstance3D.new()
	var beam_len: float = from_world.distance_to(to_world)
	if beam_len < 0.01:
		return

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = beam_len
	beam.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = mat

	# Position at midpoint, rotate to align
	var midpoint: Vector3 = (from_world + to_world) / 2.0
	beam.position = midpoint
	beam.look_at(to_world, Vector3.UP)
	beam.rotation.x += PI / 2.0  # Cylinder aligns along Y, need it along Z

	add_child(beam)

	# Impact flash at hit point
	_spawn_impact_flash(to_world, Color(1.0, 0.3, 0.1))

	# Auto-remove after delay
	_remove_after(beam, 0.5)


## Show a shotgun cone blast effect.
func show_shotgun(start_pos: Vector2i, direction: Vector2i) -> void:
	if _level_renderer == null:
		return
	var from_world: Vector3 = _level_renderer.grid_to_world(start_pos) + Vector3(0, 0.5, 0)
	var dir_world := Vector3(direction.x, 0, direction.y).normalized()

	# Three short beams in a fan pattern
	for angle_offset: float in [-0.4, 0.0, 0.4]:
		var rotated_dir: Vector3 = dir_world.rotated(Vector3.UP, angle_offset)
		var end_pos: Vector3 = from_world + rotated_dir * 3.0

		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.08
		cyl.height = 3.0
		beam.mesh = cyl

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6, 0.0, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.0)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam.material_override = mat

		var midpoint: Vector3 = (from_world + end_pos) / 2.0
		beam.position = midpoint
		beam.look_at(end_pos, Vector3.UP)
		beam.rotation.x += PI / 2.0

		add_child(beam)
		_remove_after(beam, 0.4)


## Flash at a world position when something is hit.
func show_damage_flash(grid_pos: Vector2i) -> void:
	if _level_renderer == null:
		return
	var world_pos: Vector3 = _level_renderer.grid_to_world(grid_pos) + Vector3(0, 0.5, 0)
	_spawn_impact_flash(world_pos, Color(1.0, 0.2, 0.2))


## Show a shove effect (arrow pushing outward).
func show_shove(from_pos: Vector2i, direction: Vector2i) -> void:
	if _level_renderer == null:
		return
	var from_world: Vector3 = _level_renderer.grid_to_world(from_pos) + Vector3(0, 0.5, 0)
	var to_world: Vector3 = from_world + Vector3(direction.x, 0, direction.y)

	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.2
	cone_mesh.height = 0.5
	cone.mesh = cone_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.6, 0.2, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.5, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone.material_override = mat

	cone.position = (from_world + to_world) / 2.0
	cone.look_at(to_world, Vector3.UP)
	cone.rotation.x += PI / 2.0

	add_child(cone)
	_remove_after(cone, 0.4)


## Show EMP pulse (expanding ring).
func show_emp(grid_pos: Vector2i) -> void:
	if _level_renderer == null:
		return
	var world_pos: Vector3 = _level_renderer.grid_to_world(grid_pos) + Vector3(0, 0.3, 0)

	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 1.2
	torus.bottom_radius = 1.2
	torus.height = 0.05
	ring.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.2, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.2, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat

	ring.position = world_pos
	add_child(ring)
	_remove_after(ring, 0.5)


## Show explosion (self destruct).
func show_explosion(grid_pos: Vector2i) -> void:
	if _level_renderer == null:
		return
	var world_pos: Vector3 = _level_renderer.grid_to_world(grid_pos) + Vector3(0, 0.5, 0)

	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	ball.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.material_override = mat

	ball.position = world_pos
	add_child(ball)
	_remove_after(ball, 0.5)


## Show teleport flash (at destination).
func show_teleport(grid_pos: Vector2i) -> void:
	if _level_renderer == null:
		return
	var world_pos: Vector3 = _level_renderer.grid_to_world(grid_pos) + Vector3(0, 0.5, 0)
	_spawn_impact_flash(world_pos, Color(0.8, 0.0, 1.0))


## Show shield activation.
func show_shield_activate(grid_pos: Vector2i) -> void:
	if _level_renderer == null:
		return
	var world_pos: Vector3 = _level_renderer.grid_to_world(grid_pos) + Vector3(0, 0.5, 0)

	var pulse := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	pulse.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse.material_override = mat

	pulse.position = world_pos
	add_child(pulse)
	_remove_after(pulse, 0.4)


func _spawn_impact_flash(world_pos: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	flash.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = mat

	flash.position = world_pos
	add_child(flash)
	_remove_after(flash, 0.3)


func _remove_after(node: Node3D, seconds: float) -> void:
	var timer := Timer.new()
	timer.wait_time = seconds
	timer.one_shot = true
	timer.timeout.connect(func() -> void:
		node.queue_free()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
