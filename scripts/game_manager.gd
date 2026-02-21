## Top-level game state machine for GOTO.
## Manages the planning → countdown → execution → round-end loop.
extends Node

enum GameState { PLANNING, COUNTDOWN, EXECUTING, ROUND_END, GAME_OVER, VICTORY }

signal state_changed(new_state: GameState)
signal instruction_pool_updated(pool: Array)
signal turn_order_updated(order: Array)

var current_state: GameState = GameState.PLANNING
var instruction_pool: Array = []  # Available instructions this round
var robots: Array[Robot] = []
var enemies: Array[Enemy] = []
var level: LevelGenerator
var turn_engine: TurnEngine = TurnEngine.new()

var _countdown_timer: float = 0.0
var _countdown_active: bool = false
var _execution_timer: float = 0.0
var _execution_delay: float = 0.78  # Seconds between each turn step
var _has_key: bool = false

# Reference to the main scene for spawning entities
var _main_scene: Node3D
var _level_renderer: Node3D


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	match current_state:
		GameState.COUNTDOWN:
			_process_countdown(delta)
		GameState.EXECUTING:
			_process_execution(delta)


func initialize(main_scene: Node3D, renderer: Node3D) -> void:
	_main_scene = main_scene
	_level_renderer = renderer

	# Generate level
	level = LevelGenerator.new()
	level.generate(16, 16)

	# Spawn robots
	for i: int in range(4):
		var robot := Robot.new()
		robot.robot_id = i
		robot.grid_pos = level.robot_spawns[i]
		robot.facing = randi_range(0, 3) as Robot.Direction
		robot.name = "Robot_%d" % i
		robots.append(robot)
		_main_scene.add_child(robot)
		robot.destroyed.connect(_on_robot_destroyed)

	# Spawn enemies
	for spawn_data: Dictionary in level.enemy_spawns:
		var enemy := Enemy.new()
		enemy.grid_pos = spawn_data["pos"]
		enemy.pattern = spawn_data["instructions"]
		enemy.name = "Enemy_%d" % enemies.size()
		enemies.append(enemy)
		_main_scene.add_child(enemy)
		enemy.destroyed.connect(_on_enemy_destroyed)

	# Setup turn engine
	turn_engine.setup(level, robots, enemies)
	turn_engine.round_complete.connect(_on_round_complete)
	turn_engine.entity_fell.connect(_on_entity_fell)

	# Generate initial instruction pool and start planning
	_start_planning_phase()


func _start_planning_phase() -> void:
	current_state = GameState.PLANNING
	state_changed.emit(current_state)

	# Generate pool: 3 instructions per alive robot
	var alive_count: int = 0
	for robot: Robot in robots:
		if robot.is_alive:
			alive_count += 1
	var pool_size: int = maxi(alive_count * 3, 12)
	instruction_pool = InstructionsDB.generate_pool(pool_size)
	instruction_pool_updated.emit(instruction_pool)

	# Build and expose turn order
	var order: Array = turn_engine.build_turn_order()
	turn_order_updated.emit(order)

	# Update entity world positions
	_sync_entity_positions()


func start_countdown() -> void:
	if current_state != GameState.PLANNING:
		return
	_countdown_timer = 5.0
	_countdown_active = true
	current_state = GameState.COUNTDOWN
	state_changed.emit(current_state)


func cancel_countdown() -> void:
	if current_state != GameState.COUNTDOWN:
		return
	_countdown_active = false
	current_state = GameState.PLANNING
	state_changed.emit(current_state)


func _process_countdown(delta: float) -> void:
	if not _countdown_active:
		return
	_countdown_timer -= delta
	if _countdown_timer <= 0.0:
		_countdown_active = false
		_start_execution()


func _start_execution() -> void:
	current_state = GameState.EXECUTING
	state_changed.emit(current_state)
	_execution_timer = 0.0


func _process_execution(delta: float) -> void:
	_execution_timer += delta
	if _execution_timer >= _execution_delay:
		_execution_timer = 0.0
		var has_more: bool = turn_engine.execute_step()
		_sync_entity_positions()
		if not has_more:
			pass  # round_complete signal handles transition


func _on_round_complete() -> void:
	# Check victory condition
	for robot: Robot in robots:
		if robot.is_alive and robot.grid_pos == level.exit_position:
			if _has_key or level.key_positions.is_empty():
				current_state = GameState.VICTORY
				state_changed.emit(current_state)
				return

	# Check for key pickup
	for robot: Robot in robots:
		if robot.is_alive:
			for key_pos: Vector2i in level.key_positions:
				if robot.grid_pos == key_pos:
					_has_key = true
					# Open locked doors
					for y: int in range(level.height):
						for x: int in range(level.width):
							if level.wall_grid[y][x] == LevelGenerator.WallCell.DOOR_LOCKED:
								level.wall_grid[y][x] = LevelGenerator.WallCell.EMPTY

	# Check if all robots dead
	var any_alive: bool = false
	for robot: Robot in robots:
		if robot.is_alive:
			any_alive = true
			break
	if not any_alive:
		current_state = GameState.GAME_OVER
		state_changed.emit(current_state)
		return

	# Next round
	_start_planning_phase()


func _on_robot_destroyed(robot: Robot) -> void:
	pass  # Handled in round_complete check


func _on_enemy_destroyed(enemy: Enemy) -> void:
	pass  # Enemy removed from turn order naturally


func _on_entity_fell(entity: Node3D) -> void:
	pass  # Visual feedback could be added here


## Assign an instruction from the pool to a robot's buffer.
func assign_instruction(pool_index: int, robot_id: int) -> bool:
	if pool_index < 0 or pool_index >= instruction_pool.size():
		return false
	if robot_id < 0 or robot_id >= robots.size():
		return false
	var robot: Robot = robots[robot_id]
	if not robot.is_alive:
		return false
	var instr: Instruction = instruction_pool[pool_index]
	if robot.add_instruction(instr):
		instruction_pool.remove_at(pool_index)
		instruction_pool_updated.emit(instruction_pool)
		return true
	return false


## Return an instruction from a robot's buffer to the pool.
func return_instruction(robot_id: int, buffer_index: int) -> bool:
	if robot_id < 0 or robot_id >= robots.size():
		return false
	var robot: Robot = robots[robot_id]
	var instr: Instruction = robot.remove_instruction(buffer_index)
	if instr != null:
		instruction_pool.append(instr)
		instruction_pool_updated.emit(instruction_pool)
		return true
	return false


## Swap turn order for a robot.
func swap_robot_turn_order(robot_idx_in_order: int, direction: int) -> void:
	var target_idx: int = robot_idx_in_order + direction
	if turn_engine.swap_turn_order(robot_idx_in_order, target_idx):
		turn_order_updated.emit(turn_engine.get_turn_order())


func _sync_entity_positions() -> void:
	if _level_renderer == null:
		return
	var renderer: Node3D = _level_renderer
	var move_duration: float = 0.25  # Smooth slide duration
	for robot: Robot in robots:
		if robot.is_alive:
			var target: Vector3 = renderer.grid_to_world(robot.grid_pos)
			if robot.position.distance_to(target) > 0.01:
				var tween: Tween = robot.create_tween()
				tween.tween_property(robot, "position", target, move_duration)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			else:
				robot.position = target
		else:
			robot.visible = false
	for enemy: Enemy in enemies:
		if enemy.is_alive:
			var target: Vector3 = renderer.grid_to_world(enemy.grid_pos)
			if enemy.position.distance_to(target) > 0.01:
				var tween: Tween = enemy.create_tween()
				tween.tween_property(enemy, "position", target, move_duration)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			else:
				enemy.position = target
		else:
			enemy.visible = false


## Get countdown time remaining.
func get_countdown_time() -> float:
	return _countdown_timer
