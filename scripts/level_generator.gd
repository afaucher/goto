## Procedural level generator for GOTO.
## Generates a 2-layer voxel map: floor and walls.
class_name LevelGenerator
extends RefCounted

## Cell types for each layer
enum FloorCell { SOLID, GAP }
enum WallCell { EMPTY, WALL, DOOR_LOCKED, DOOR_OPEN, EXIT, KEY_SPAWN }

## Generated level data
var width: int = 16
var height: int = 16
var floor_grid: Array = []  # 2D array of FloorCell
var wall_grid: Array = []   # 2D array of WallCell
var robot_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Dictionary] = []  # [{pos: Vector2i, instructions: Array}]
var key_positions: Array[Vector2i] = []
var exit_position: Vector2i = Vector2i.ZERO


func generate(p_width: int = 16, p_height: int = 16, p_seed: int = -1) -> void:
	width = p_width
	height = p_height
	if p_seed >= 0:
		seed(p_seed)
	else:
		randomize()

	_init_grids()
	_create_perimeter()
	_generate_gaps()
	_generate_interior_walls()
	_place_objectives()
	_place_robot_spawns()
	_place_enemies()


func _init_grids() -> void:
	floor_grid.clear()
	wall_grid.clear()
	for y: int in range(height):
		var floor_row: Array = []
		var wall_row: Array = []
		for x: int in range(width):
			floor_row.append(FloorCell.SOLID)
			wall_row.append(WallCell.EMPTY)
		floor_grid.append(floor_row)
		wall_grid.append(wall_row)


func _create_perimeter() -> void:
	for x: int in range(width):
		# Top and bottom edges: mix of walls and gaps
		if randi() % 3 == 0:
			floor_grid[0][x] = FloorCell.GAP
		else:
			wall_grid[0][x] = WallCell.WALL
		if randi() % 3 == 0:
			floor_grid[height - 1][x] = FloorCell.GAP
		else:
			wall_grid[height - 1][x] = WallCell.WALL
	for y: int in range(height):
		if randi() % 3 == 0:
			floor_grid[y][0] = FloorCell.GAP
		else:
			wall_grid[y][0] = WallCell.WALL
		if randi() % 3 == 0:
			floor_grid[y][width - 1] = FloorCell.GAP
		else:
			wall_grid[y][width - 1] = WallCell.WALL


## Generate clustered gaps using cellular automata
func _generate_gaps() -> void:
	# Seed random gaps in interior (skip perimeter)
	for y: int in range(2, height - 2):
		for x: int in range(2, width - 2):
			if randf() < 0.12:
				floor_grid[y][x] = FloorCell.GAP

	# Smooth with cellular automata (3 passes)
	for _pass: int in range(3):
		var new_grid: Array = []
		for y: int in range(height):
			var row: Array = []
			for x: int in range(width):
				row.append(floor_grid[y][x])
			new_grid.append(row)

		for y: int in range(2, height - 2):
			for x: int in range(2, width - 2):
				var gap_neighbors: int = _count_gap_neighbors(x, y)
				if gap_neighbors >= 4:
					new_grid[y][x] = FloorCell.GAP
				elif gap_neighbors <= 1:
					new_grid[y][x] = FloorCell.SOLID
		floor_grid = new_grid


func _count_gap_neighbors(x: int, y: int) -> int:
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				if floor_grid[ny][nx] == FloorCell.GAP:
					count += 1
	return count


## Generate interior walls to create rooms and corridors
func _generate_interior_walls() -> void:
	# Place some random wall segments
	var wall_count: int = (width * height) / 12
	for _i: int in range(wall_count):
		var x: int = randi_range(2, width - 3)
		var y: int = randi_range(2, height - 3)
		if floor_grid[y][x] == FloorCell.SOLID and wall_grid[y][x] == WallCell.EMPTY:
			wall_grid[y][x] = WallCell.WALL
			# Extend wall in a random direction
			var dir: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP].pick_random()
			var length: int = randi_range(1, 3)
			for step: int in range(length):
				var nx: int = x + dir.x * (step + 1)
				var ny: int = y + dir.y * (step + 1)
				if nx > 1 and nx < width - 2 and ny > 1 and ny < height - 2:
					if floor_grid[ny][nx] == FloorCell.SOLID:
						wall_grid[ny][nx] = WallCell.WALL


func _place_objectives() -> void:
	# Place exit in a far corner area
	exit_position = _find_valid_position(width - 4, height - 4, width - 2, height - 2)
	wall_grid[exit_position.y][exit_position.x] = WallCell.EXIT

	# Place a key somewhere in the middle area
	var key_pos: Vector2i = _find_valid_position(3, 3, width - 4, height - 4)
	wall_grid[key_pos.y][key_pos.x] = WallCell.KEY_SPAWN
	key_positions.append(key_pos)

	# Place a locked door between spawn and exit
	var door_x: int = width / 2
	var door_y: int = height / 2
	var door_pos: Vector2i = _find_valid_position(door_x - 2, door_y - 2, door_x + 2, door_y + 2)
	wall_grid[door_pos.y][door_pos.x] = WallCell.DOOR_LOCKED


func _place_robot_spawns() -> void:
	robot_spawns.clear()
	# Place 4 robots near the top-left area
	for i: int in range(4):
		var pos: Vector2i = _find_valid_position(2, 2, 5, 5)
		# Make sure we don't stack on another spawn
		var attempts: int = 0
		while pos in robot_spawns and attempts < 20:
			pos = _find_valid_position(2, 2, 6, 6)
			attempts += 1
		robot_spawns.append(pos)


func _place_enemies() -> void:
	enemy_spawns.clear()
	var enemy_count: int = randi_range(3, 6)
	# Enemy instruction patterns
	var patterns: Array[Array] = [
		[Instruction.Type.MOVE_FORWARD, Instruction.Type.MOVE_FORWARD,
			Instruction.Type.FIRE_LASER, Instruction.Type.TURN_LEFT],
		[Instruction.Type.MOVE_FORWARD, Instruction.Type.TURN_RIGHT,
			Instruction.Type.MOVE_FORWARD, Instruction.Type.FIRE_LASER],
		[Instruction.Type.TURN_LEFT, Instruction.Type.FIRE_LASER,
			Instruction.Type.TURN_RIGHT, Instruction.Type.FIRE_LASER],
		[Instruction.Type.MOVE_FORWARD, Instruction.Type.MOVE_FORWARD,
			Instruction.Type.TURN_RIGHT, Instruction.Type.MOVE_FORWARD],
	]

	for _i: int in range(enemy_count):
		var pos: Vector2i = _find_valid_position(4, 4, width - 3, height - 3)
		var pattern: Array = patterns[randi() % patterns.size()]
		enemy_spawns.append({"pos": pos, "instructions": pattern})


## Find a valid (solid floor, no wall) position in the given rectangle.
func _find_valid_position(min_x: int, min_y: int, max_x: int, max_y: int) -> Vector2i:
	var attempts: int = 0
	while attempts < 100:
		var x: int = randi_range(min_x, max_x)
		var y: int = randi_range(min_y, max_y)
		if x >= 0 and x < width and y >= 0 and y < height:
			if floor_grid[y][x] == FloorCell.SOLID and wall_grid[y][x] == WallCell.EMPTY:
				return Vector2i(x, y)
		attempts += 1
	# Fallback: return center
	return Vector2i(width / 2, height / 2)


## Check if a grid position is walkable (solid floor, no wall)
func is_walkable(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false
	return floor_grid[pos.y][pos.x] == FloorCell.SOLID and wall_grid[pos.y][pos.x] == WallCell.EMPTY


## Check if a grid position is a gap (fatal fall)
func is_gap(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return true  # Out of bounds = gap
	return floor_grid[pos.y][pos.x] == FloorCell.GAP
