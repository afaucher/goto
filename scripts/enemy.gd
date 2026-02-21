## Enemy entity for GOTO.
## Has a repeating instruction pattern that loops forever.
## Visually distinct: dark red/black body, single menacing red eye, spiky silhouette, "E" label.
class_name Enemy
extends Node3D

signal destroyed(enemy: Enemy)

var hp: int = 3
var grid_pos: Vector2i = Vector2i.ZERO
var facing: Robot.Direction = Robot.Direction.NORTH
var is_alive: bool = true
var is_disabled: bool = false  # EMP'd
var is_telegraph_visible: bool = false

## Planned instructions for the current round (3 rounds)
var intent_buffer: Array[Instruction.Type] = []

var _body_mesh: MeshInstance3D
var _eye_mesh: MeshInstance3D
var _label: Label3D
var _spike_top: MeshInstance3D
var _intent_line: MeshInstance3D
var _intent_sphere: MeshInstance3D


func _ready() -> void:
	_build_visuals()
	# Apply initial facing (may be set before add_child)
	set_facing(facing)


func _build_visuals() -> void:
	# Body: slightly smaller, darker, more menacing
	_body_mesh = MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.6, 0.6, 0.6)
	_body_mesh.mesh = body_box
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.25, 0.08, 0.08)
	body_mat.roughness = 0.3
	body_mat.metallic = 0.5
	_body_mesh.material_override = body_mat
	_body_mesh.position = Vector3(0, 0.3, 0)
	add_child(_body_mesh)

	# Spike on top (menacing, distinguishes from robots)
	_spike_top = MeshInstance3D.new()
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.12
	spike_mesh.height = 0.25
	_spike_top.mesh = spike_mesh
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.6, 0.1, 0.1)
	spike_mat.metallic = 0.6
	_spike_top.material_override = spike_mat
	_spike_top.position = Vector3(0, 0.42, 0)
	_body_mesh.add_child(_spike_top)

	# Single large red eye (menacing)
	_eye_mesh = MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.12
	eye_sphere.height = 0.24
	_eye_mesh.mesh = eye_sphere
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.0, 0.0)
	eye_mat.emission_energy_multiplier = 2.0
	_eye_mesh.material_override = eye_mat
	# Fixed local position: forward is -Z in local space
	_eye_mesh.position = Vector3(0, 0.05, -0.32)
	_body_mesh.add_child(_eye_mesh)

	# Floating hostile label
	_label = Label3D.new()
	_label.text = "E"
	_label.font_size = 40
	_label.modulate = Color(1.0, 0.2, 0.2)
	_label.outline_modulate = Color.BLACK
	_label.outline_size = 8
	_label.position = Vector3(0, 1.0, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

	# Intent Visualizer (red line for lasers)
	_intent_line = MeshInstance3D.new()
	var intent_cyl := CylinderMesh.new()
	intent_cyl.top_radius = 0.05
	intent_cyl.bottom_radius = 0.05
	_intent_line.mesh = intent_cyl
	var intent_mat := StandardMaterial3D.new()
	intent_mat.albedo_color = Color(1, 0, 0, 0.4)
	intent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	intent_mat.emission_enabled = true
	intent_mat.emission = Color(1, 0, 0)
	intent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_intent_line.material_override = intent_mat
	_intent_line.visible = false
	add_child(_intent_line)

	# Intent Target (sphere for end position)
	_intent_sphere = MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	_intent_sphere.mesh = sphere_mesh
	_intent_sphere.material_override = intent_mat
	_intent_sphere.visible = false
	add_child(_intent_sphere)


## Set facing direction.
func set_facing(dir: Robot.Direction) -> void:
	facing = dir
	# Body rotation handles eye/spike orientation since they are children
	_body_mesh.rotation.y = _direction_to_angle(dir)


## Get the next instruction type from the intent buffer.
func pop_next_instruction_type() -> Instruction.Type:
	if is_disabled:
		is_disabled = false
		_update_intent_visuals()
		return Instruction.Type.WAIT
	if intent_buffer.is_empty():
		_update_intent_visuals()
		return Instruction.Type.WAIT
	var next := intent_buffer.pop_front()
	_update_intent_visuals()
	return next


## Plan actions for the next 3 rounds.
## This is called by GameManager at the start of the PLANNING phase.
func plan_intent(robots: Array[Robot], level: LevelGenerator) -> void:
	intent_buffer.clear()
	
	# Simple Greedy AI for now: 
	# 1. Can I shoot a robot right now? If so, fire.
	# 2. Otherwise, rotate towards nearest robot.
	# 3. Otherwise, move forward if safe.
	
	# Find nearest robot
	var nearest_robot: Robot = null
	var min_dist: float = 9999.0
	for robot in robots:
		if robot.is_alive:
			var d := Vector2(grid_pos).distance_to(Vector2(robot.grid_pos))
			if d < min_dist:
				min_dist = d
				nearest_robot = robot
	
	# Plan 3 steps
	var simulated_pos := grid_pos
	var simulated_facing := facing
	
	for i in range(3):
		var choice := Instruction.Type.WAIT
		
		if nearest_robot:
			var to_robot := nearest_robot.grid_pos - simulated_pos
			var forward_vec := Robot.direction_to_vec(simulated_facing)
			
			# Check line of sight
			var is_aligned := false
			if to_robot.x == 0 and signi(to_robot.y) == forward_vec.y: is_aligned = true
			if to_robot.y == 0 and signi(to_robot.x) == forward_vec.x: is_aligned = true
			
			if is_aligned and to_robot.length() < 10:
				choice = Instruction.Type.FIRE_LASER
			else:
				# Try to face the robot
				var desired_facing := simulated_facing
				if abs(to_robot.x) > abs(to_robot.y):
					desired_facing = Robot.Direction.EAST if to_robot.x > 0 else Robot.Direction.WEST
				else:
					desired_facing = Robot.Direction.SOUTH if to_robot.y > 0 else Robot.Direction.NORTH
				
				if desired_facing != simulated_facing:
					# Simple choice: turn towards it
					choice = Instruction.Type.TURN_RIGHT # Placeholder: simple turn logic
					# Determine turn direction
					var diff := (int(desired_facing) - int(simulated_facing) + 4) % 4
					if diff == 1: choice = Instruction.Type.TURN_RIGHT
					elif diff == 3: choice = Instruction.Type.TURN_LEFT
					elif diff == 2: choice = Instruction.Type.U_TURN
					
					# Update simulation
					if choice == Instruction.Type.TURN_RIGHT: simulated_facing = Robot.turn_right_dir(simulated_facing)
					elif choice == Instruction.Type.TURN_LEFT: simulated_facing = Robot.turn_left_dir(simulated_facing)
					elif choice == Instruction.Type.U_TURN: simulated_facing = Robot.reverse_dir(simulated_facing)
				else:
					# Move forward if safe
					var target := simulated_pos + forward_vec
					if level.is_walkable(target) and not level.is_gap(target):
						choice = Instruction.Type.MOVE_FORWARD
						simulated_pos = target
					else:
						choice = Instruction.Type.WAIT
		
		intent_buffer.append(choice)
	
	_update_intent_visuals()


func _update_intent_visuals() -> void:
	if _intent_line == null: return
	
	_intent_line.visible = false
	_intent_sphere.visible = false
	
	# Only show if telegraph is active
	if not visible or intent_buffer.is_empty() or not is_telegraph_visible:
		return
	
	# For now, just telegraph Laser Fire if it's anywhere in the intent
	var fire_index := -1
	for i in range(intent_buffer.size()):
		if intent_buffer[i] == Instruction.Type.FIRE_LASER:
			fire_index = i
			break
	
	# Also show movement arrows if first action is move
	if intent_buffer[0] == Instruction.Type.MOVE_FORWARD:
		_intent_sphere.visible = true
		var forward := _direction_to_vector3(facing)
		_intent_sphere.position = forward + Vector3(0, 0.3, 0)
	
	if fire_index != -1:
		_intent_line.visible = true
		
		var forward := _direction_to_vector3(facing)
		# Position line
		_intent_line.position = forward * 5.0 + Vector3(0, 0.3, 0)
		_intent_line.look_at(global_position + forward * 10.0, Vector3.UP)
		_intent_line.rotation.x += PI/2
		
		# Extend line
		var cyl: CylinderMesh = _intent_line.mesh
		cyl.height = 10.0


## Take damage.
func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		is_alive = false
		destroyed.emit(self)
		visible = false


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
