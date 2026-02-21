## Turn execution engine for GOTO.
## Processes one round: each entity executes one instruction in turn order.
class_name TurnEngine
extends RefCounted

signal turn_started(entity_index: int, total_entities: int)
signal instruction_executing(entity: Node3D, instruction_type: Instruction.Type)
signal turn_step_complete(entity_index: int)
signal round_complete()
signal entity_fell(entity: Node3D)
signal entity_damaged(target: Node3D, amount: int)
signal vfx_requested(effect_name: String, data: Dictionary)

var _level: LevelGenerator
var _robots: Array[Robot] = []
var _enemies: Array[Enemy] = []
var _turn_order: Array = []  # Array of Node3D (Robot or Enemy)
var _current_round: int = 0  # 0, 1, 2 (3 rounds total)
var _current_entity_idx: int = 0  # Index within turn order for current round
const MAX_ROUNDS: int = 3


func setup(level: LevelGenerator, robots: Array[Robot], enemies: Array[Enemy]) -> void:
	_level = level
	_robots = robots
	_enemies = enemies


## Build randomized turn order. Robots can be reordered before execution.
func build_turn_order() -> Array:
	_turn_order.clear()
	# Combine all alive entities
	for robot: Robot in _robots:
		if robot.is_alive:
			_turn_order.append(robot)
	for enemy: Enemy in _enemies:
		if enemy.is_alive:
			_turn_order.append(enemy)
	# Shuffle
	_turn_order.shuffle()
	_current_round = 0
	_current_entity_idx = 0
	return _turn_order


## Swap two adjacent entries in turn order. Returns true if swapped.
func swap_turn_order(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_b < 0:
		return false
	if idx_a >= _turn_order.size() or idx_b >= _turn_order.size():
		return false
	var temp: Node3D = _turn_order[idx_a]
	_turn_order[idx_a] = _turn_order[idx_b]
	_turn_order[idx_b] = temp
	return true


## Execute one step (one entity's instruction in current round). Returns true if more steps remain.
func execute_step() -> bool:
	if _current_round >= MAX_ROUNDS:
		round_complete.emit()
		return false

	if _turn_order.is_empty():
		round_complete.emit()
		return false

	var overall_step: int = _current_round * _turn_order.size() + _current_entity_idx
	var total_steps: int = MAX_ROUNDS * _turn_order.size()
	turn_started.emit(overall_step, total_steps)

	var entity: Node3D = _turn_order[_current_entity_idx]

	if entity is Robot:
		_execute_robot_step(entity as Robot)
	elif entity is Enemy:
		_execute_enemy_step(entity as Enemy)

	turn_step_complete.emit(overall_step)

	# Advance to next entity
	_current_entity_idx += 1
	if _current_entity_idx >= _turn_order.size():
		_current_entity_idx = 0
		_current_round += 1

	if _current_round >= MAX_ROUNDS:
		round_complete.emit()
		return false
	return true


func _execute_robot_step(robot: Robot) -> void:
	if not robot.is_alive:
		return
	var instr: Instruction = robot.pop_next_instruction()
	if instr == null:
		return
	instruction_executing.emit(robot, instr.type)
	_apply_instruction(robot, instr.type, robot.facing, robot.grid_pos)
	robot.instruction_executed.emit(robot, instr)


func _execute_enemy_step(enemy: Enemy) -> void:
	if not enemy.is_alive:
		return
	var instr_type: Instruction.Type = enemy.pop_next_instruction_type()
	instruction_executing.emit(enemy, instr_type)
	_apply_instruction(enemy, instr_type, enemy.facing, enemy.grid_pos)


func _apply_instruction(entity: Node3D, instr_type: Instruction.Type,
		facing: Robot.Direction, grid_pos: Vector2i) -> void:
	var forward: Vector2i = Robot.direction_to_vec(facing)
	match instr_type:
		Instruction.Type.MOVE_FORWARD:
			_try_move(entity, grid_pos + forward)
		Instruction.Type.MOVE_BACKWARD:
			_try_move(entity, grid_pos - forward)
		Instruction.Type.TURN_LEFT:
			_set_entity_facing(entity, Robot.turn_left_dir(facing))
		Instruction.Type.TURN_RIGHT:
			_set_entity_facing(entity, Robot.turn_right_dir(facing))
		Instruction.Type.U_TURN:
			_set_entity_facing(entity, Robot.reverse_dir(facing))
		Instruction.Type.STRAFE_LEFT:
			var left_dir: Robot.Direction = Robot.turn_left_dir(facing)
			_try_move(entity, grid_pos + Robot.direction_to_vec(left_dir))
		Instruction.Type.STRAFE_RIGHT:
			var right_dir: Robot.Direction = Robot.turn_right_dir(facing)
			_try_move(entity, grid_pos + Robot.direction_to_vec(right_dir))
		Instruction.Type.SPRINT:
			var step1: Vector2i = grid_pos + forward
			if _try_move(entity, step1):
				_try_move(entity, step1 + forward)
		Instruction.Type.SHOVE_FORWARD:
			_do_shove(entity, forward, 2)
		Instruction.Type.SHOVE_ALL:
			_do_shove_all(entity)
		Instruction.Type.FIRE_LASER:
			_do_fire_laser(entity, forward, grid_pos)
		Instruction.Type.WAIT:
			pass  # Do nothing
		Instruction.Type.JUMP:
			_try_move(entity, grid_pos + forward * 2, true)
		Instruction.Type.SHIELD:
			if entity is Robot:
				(entity as Robot).activate_shield()
				vfx_requested.emit("shield", {"pos": grid_pos})
		Instruction.Type.FIRE_SHOTGUN:
			_do_fire_shotgun(entity, forward, grid_pos)
		Instruction.Type.SELF_DESTRUCT:
			_do_self_destruct(entity)
		Instruction.Type.EMP:
			_do_emp(entity)
		Instruction.Type.OVERCLOCK:
			pass  # Handled by game_manager checking for overclock
		Instruction.Type.REPAIR:
			if entity is Robot:
				(entity as Robot).heal(1)
		Instruction.Type.TELEPORT:
			_do_teleport(entity)


## Try to move an entity to a new grid position. Returns true if moved.
func _try_move(entity: Node3D, target: Vector2i, skip_gaps: bool = false) -> bool:
	# Check if target is a gap
	if _level.is_gap(target) and not skip_gaps:
		_set_entity_grid_pos(entity, target)
		entity_fell.emit(entity)
		if entity is Robot:
			(entity as Robot).take_damage(Robot.MAX_HP)
		elif entity is Enemy:
			(entity as Enemy).take_damage(100)
		return false

	# Check if target is walkable
	if not _level.is_walkable(target):
		return false

	# Check for entity collision at target
	var blocking: Node3D = _get_entity_at(target)
	if blocking != null:
		return false

	_set_entity_grid_pos(entity, target)
	return true


func _set_entity_grid_pos(entity: Node3D, pos: Vector2i) -> void:
	if entity is Robot:
		(entity as Robot).grid_pos = pos
	elif entity is Enemy:
		(entity as Enemy).grid_pos = pos


func _set_entity_facing(entity: Node3D, dir: Robot.Direction) -> void:
	if entity is Robot:
		(entity as Robot).set_facing(dir)
	elif entity is Enemy:
		(entity as Enemy).set_facing(dir)


func _get_entity_facing(entity: Node3D) -> Robot.Direction:
	if entity is Robot:
		return (entity as Robot).facing
	elif entity is Enemy:
		return (entity as Enemy).facing
	return Robot.Direction.NORTH


func _get_entity_grid_pos(entity: Node3D) -> Vector2i:
	if entity is Robot:
		return (entity as Robot).grid_pos
	elif entity is Enemy:
		return (entity as Enemy).grid_pos
	return Vector2i.ZERO


func _get_entity_at(pos: Vector2i) -> Node3D:
	for robot: Robot in _robots:
		if robot.is_alive and robot.grid_pos == pos:
			return robot
	for enemy: Enemy in _enemies:
		if enemy.is_alive and enemy.grid_pos == pos:
			return enemy
	return null


func _do_shove(entity: Node3D, direction: Vector2i, distance: int) -> void:
	var entity_pos: Vector2i = _get_entity_grid_pos(entity)
	var target_pos: Vector2i = entity_pos + direction
	var target_entity: Node3D = _get_entity_at(target_pos)
	if target_entity == null:
		return
	vfx_requested.emit("shove", {"pos": entity_pos, "dir": direction})
	# Push the target entity
	for _i: int in range(distance):
		var push_target: Vector2i = _get_entity_grid_pos(target_entity) + direction
		if not _try_move(target_entity, push_target):
			break


func _do_shove_all(entity: Node3D) -> void:
	var entity_pos: Vector2i = _get_entity_grid_pos(entity)
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
	]
	for dir: Vector2i in directions:
		var adj_pos: Vector2i = entity_pos + dir
		var adj_entity: Node3D = _get_entity_at(adj_pos)
		if adj_entity != null:
			_try_move(adj_entity, adj_pos + dir)


func _do_fire_laser(entity: Node3D, direction: Vector2i, start_pos: Vector2i) -> void:
	var pos: Vector2i = start_pos + direction
	var end_pos: Vector2i = start_pos + direction  # Track where beam ends
	while pos.x >= 0 and pos.x < _level.width and pos.y >= 0 and pos.y < _level.height:
		# Hit a wall?
		if _level.wall_grid[pos.y][pos.x] == LevelGenerator.WallCell.WALL:
			end_pos = pos
			break
		if _level.wall_grid[pos.y][pos.x] == LevelGenerator.WallCell.LOCK:
			end_pos = pos
			break
		# Hit an entity?
		var hit_entity: Node3D = _get_entity_at(pos)
		if hit_entity != null and hit_entity != entity:
			_damage_entity(hit_entity, 1)
			end_pos = pos
			vfx_requested.emit("damage", {"pos": pos})
			break
		end_pos = pos
		pos += direction
	vfx_requested.emit("laser", {"start": start_pos, "end": end_pos, "dir": direction})


func _do_fire_shotgun(entity: Node3D, direction: Vector2i, start_pos: Vector2i) -> void:
	var right_dir: Robot.Direction = Robot.turn_right_dir(
		_get_entity_facing(entity))
	var left_dir: Robot.Direction = Robot.turn_left_dir(
		_get_entity_facing(entity))
	# Fire in 3 directions: forward, forward-left, forward-right
	var dirs: Array[Vector2i] = [
		direction,
		direction + Robot.direction_to_vec(left_dir),
		direction + Robot.direction_to_vec(right_dir),
	]
	for d: Vector2i in dirs:
		# Normalize to unit steps
		var normalized: Vector2i = Vector2i(signi(d.x), signi(d.y))
		var pos: Vector2i = start_pos + normalized
		for _range: int in range(3):
			if pos.x < 0 or pos.x >= _level.width or pos.y < 0 or pos.y >= _level.height:
				break
			var hit_entity: Node3D = _get_entity_at(pos)
			if hit_entity != null and hit_entity != entity:
				_damage_entity(hit_entity, 1)
				break
			if _level.wall_grid[pos.y][pos.x] == LevelGenerator.WallCell.WALL:
				break
			pos += normalized
	vfx_requested.emit("shotgun", {"pos": start_pos, "dir": direction})


func _do_self_destruct(entity: Node3D) -> void:
	var pos: Vector2i = _get_entity_grid_pos(entity)
	# Damage everything in radius 1
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var target: Node3D = _get_entity_at(pos + Vector2i(dx, dy))
			if target != null:
				_damage_entity(target, 3)
	# Destroy self
	vfx_requested.emit("explosion", {"pos": pos})
	_damage_entity(entity, 100)


func _do_emp(entity: Node3D) -> void:
	var pos: Vector2i = _get_entity_grid_pos(entity)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var target: Node3D = _get_entity_at(pos + Vector2i(dx, dy))
			if target is Enemy:
				(target as Enemy).is_disabled = true
	vfx_requested.emit("emp", {"pos": pos})


func _do_teleport(entity: Node3D) -> void:
	var pos: Vector2i = _get_entity_grid_pos(entity)
	var valid_tiles: Array[Vector2i] = []
	for dy: int in range(-5, 6):
		for dx: int in range(-5, 6):
			var target: Vector2i = pos + Vector2i(dx, dy)
			if _level.is_walkable(target) and _get_entity_at(target) == null:
				valid_tiles.append(target)
	if valid_tiles.size() > 0:
		var chosen: Vector2i = valid_tiles[randi() % valid_tiles.size()]
		_set_entity_grid_pos(entity, chosen)
		vfx_requested.emit("teleport", {"pos": chosen})


func _damage_entity(entity: Node3D, amount: int) -> void:
	entity_damaged.emit(entity, amount)
	if entity is Robot:
		(entity as Robot).take_damage(amount)
	elif entity is Enemy:
		(entity as Enemy).take_damage(amount)


## Get the current turn order for display.
func get_turn_order() -> Array:
	return _turn_order


## Get current step index (overall, across all rounds).
func get_current_step() -> int:
	return _current_round * _turn_order.size() + _current_entity_idx


## Get total steps in this execution (3 rounds × entities).
func get_total_steps() -> int:
	return MAX_ROUNDS * _turn_order.size()
