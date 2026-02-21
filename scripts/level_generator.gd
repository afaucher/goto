## Procedural level generator for GOTO.
## Generates a 2-layer voxel map: floor and walls.
## Creates a room-based layout with walls as dividers between rooms.
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
	_generate_rooms()
	_generate_gap_clusters()
	_place_objectives()
	_place_robot_spawns()
	_place_enemies()
	_ensure_connectivity()


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
	# Solid wall perimeter (cleaner than random mix)
	for x: int in range(width):
		wall_grid[0][x] = WallCell.WALL
		wall_grid[height - 1][x] = WallCell.WALL
	for y: int in range(height):
		wall_grid[y][0] = WallCell.WALL
		wall_grid[y][width - 1] = WallCell.WALL


## Generate rooms by placing wall dividers with doorways
func _generate_rooms() -> void:
	# Subdivide the arena with a few horizontal and vertical wall lines
	# Each wall line gets 1-2 doorway openings

	# Horizontal dividers
	var h_dividers: Array[int] = []
	var num_h: int = randi_range(1, 2)
	for _i: int in range(num_h):
		var y: int = randi_range(4, height - 5)
		# Avoid placing too close to another divider
		var too_close: bool = false
		for existing_y: int in h_dividers:
			if absi(y - existing_y) < 4:
				too_close = true
				break
		if too_close:
			continue
		h_dividers.append(y)
		# Place wall line
		for x: int in range(1, width - 1):
			wall_grid[y][x] = WallCell.WALL
		# Punch 1-2 doorways
		var num_doors: int = randi_range(1, 2)
		for _d: int in range(num_doors):
			var door_x: int = randi_range(2, width - 3)
			wall_grid[y][door_x] = WallCell.EMPTY
			# Make doorway 2 wide for easier navigation
			if door_x + 1 < width - 1:
				wall_grid[y][door_x + 1] = WallCell.EMPTY

	# Vertical dividers
	var v_dividers: Array[int] = []
	var num_v: int = randi_range(1, 2)
	for _i: int in range(num_v):
		var x: int = randi_range(4, width - 5)
		var too_close: bool = false
		for existing_x: int in v_dividers:
			if absi(x - existing_x) < 4:
				too_close = true
				break
		if too_close:
			continue
		v_dividers.append(x)
		for y: int in range(1, height - 1):
			# Don't overwrite horizontal divider doorways
			if wall_grid[y][x] == WallCell.EMPTY:
				wall_grid[y][x] = WallCell.WALL
		# Punch 1-2 doorways
		var num_doors: int = randi_range(1, 2)
		for _d: int in range(num_doors):
			var door_y: int = randi_range(2, height - 3)
			wall_grid[door_y][x] = WallCell.EMPTY
			if door_y + 1 < height - 1:
				wall_grid[door_y + 1][x] = WallCell.EMPTY

	# Add a few small wall features inside rooms (pillars, cover)
	var pillar_count: int = randi_range(2, 5)
	for _i: int in range(pillar_count):
		var px: int = randi_range(2, width - 3)
		var py: int = randi_range(2, height - 3)
		if wall_grid[py][px] == WallCell.EMPTY and floor_grid[py][px] == FloorCell.SOLID:
			wall_grid[py][px] = WallCell.WALL
			# Optionally extend to L-shape
			if randf() < 0.5:
				var ext_dir: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN].pick_random()
				var ex: int = px + ext_dir.x
				var ey: int = py + ext_dir.y
				if ex > 1 and ex < width - 2 and ey > 1 and ey < height - 2:
					if wall_grid[ey][ex] == WallCell.EMPTY:
						wall_grid[ey][ex] = WallCell.WALL


## Generate clustered gaps in 1-2 areas of the map
func _generate_gap_clusters() -> void:
	var num_clusters: int = randi_range(1, 2)
	for _c: int in range(num_clusters):
		# Pick a random cluster center (avoid perimeter and spawn area)
		var cx: int = randi_range(4, width - 5)
		var cy: int = randi_range(4, height - 5)
		var cluster_radius: int = randi_range(2, 3)

		for dy: int in range(-cluster_radius, cluster_radius + 1):
			for dx: int in range(-cluster_radius, cluster_radius + 1):
				var gx: int = cx + dx
				var gy: int = cy + dy
				if gx < 1 or gx >= width - 1 or gy < 1 or gy >= height - 1:
					continue
				# Circular-ish shape with some randomness
				var dist: float = sqrt(dx * dx + dy * dy)
				if dist <= cluster_radius and randf() < 0.7:
					# Don't gap over walls
					if wall_grid[gy][gx] == WallCell.EMPTY:
						floor_grid[gy][gx] = FloorCell.GAP

	# Also place some gaps along the perimeter for variety
	for x: int in range(width):
		if randi() % 4 == 0 and wall_grid[0][x] == WallCell.WALL:
			wall_grid[0][x] = WallCell.EMPTY
			floor_grid[0][x] = FloorCell.GAP
		if randi() % 4 == 0 and wall_grid[height - 1][x] == WallCell.WALL:
			wall_grid[height - 1][x] = WallCell.EMPTY
			floor_grid[height - 1][x] = FloorCell.GAP
	for y: int in range(height):
		if randi() % 4 == 0 and wall_grid[y][0] == WallCell.WALL:
			wall_grid[y][0] = WallCell.EMPTY
			floor_grid[y][0] = FloorCell.GAP
		if randi() % 4 == 0 and wall_grid[y][width - 1] == WallCell.WALL:
			wall_grid[y][width - 1] = WallCell.EMPTY
			floor_grid[y][width - 1] = FloorCell.GAP


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


## Ensure all walkable tiles are reachable from robot spawns.
## Finds disconnected regions and carves paths between them.
func _ensure_connectivity() -> void:
	if robot_spawns.is_empty():
		return

	# Find all walkable tiles
	var all_walkable: Dictionary = {}  # Vector2i -> bool
	for y: int in range(height):
		for x: int in range(width):
			if floor_grid[y][x] == FloorCell.SOLID and wall_grid[y][x] != WallCell.WALL:
				all_walkable[Vector2i(x, y)] = true

	if all_walkable.is_empty():
		return

	# Find connected regions via flood fill
	var assigned: Dictionary = {}  # Vector2i -> region_id
	var regions: Array = []  # Array of Array[Vector2i]

	for tile: Vector2i in all_walkable.keys():
		if assigned.has(tile):
			continue
		# BFS to find this region
		var region: Array[Vector2i] = []
		var queue: Array[Vector2i] = [tile]
		assigned[tile] = regions.size()
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			region.append(current)
			var neighbors: Array[Vector2i] = [
				Vector2i(current.x + 1, current.y),
				Vector2i(current.x - 1, current.y),
				Vector2i(current.x, current.y + 1),
				Vector2i(current.x, current.y - 1),
			]
			for neighbor: Vector2i in neighbors:
				if all_walkable.has(neighbor) and not assigned.has(neighbor):
					assigned[neighbor] = regions.size()
					queue.append(neighbor)
		regions.append(region)

	if regions.size() <= 1:
		return  # Already fully connected

	# Find the main region (the one containing robot spawn 0)
	var main_region_id: int = 0
	if assigned.has(robot_spawns[0]):
		main_region_id = assigned[robot_spawns[0]]

	# Merge all other regions into the main region by carving paths
	var main_tiles: Dictionary = {}  # Quick lookup for main region tiles
	for tile: Vector2i in regions[main_region_id]:
		main_tiles[tile] = true

	for region_id: int in range(regions.size()):
		if region_id == main_region_id:
			continue
		var region: Array = regions[region_id]
		# Find the closest pair of tiles between this region and main region
		var best_from: Vector2i = region[0]
		var best_to: Vector2i = regions[main_region_id][0]
		var best_dist: float = INF
		# Sample up to 20 tiles from each region for performance
		var sample_a: Array = region.slice(0, mini(20, region.size()))
		var sample_b: Array = regions[main_region_id].slice(0, mini(20, regions[main_region_id].size()))
		for a: Vector2i in sample_a:
			for b: Vector2i in sample_b:
				var dist: float = absf(a.x - b.x) + absf(a.y - b.y)
				if dist < best_dist:
					best_dist = dist
					best_from = a
					best_to = b

		# Carve a path from best_from to best_to
		_carve_corridor(best_from, best_to)
		# Add the connected tiles to main region for next merges
		for tile: Vector2i in region:
			main_tiles[tile] = true
		regions[main_region_id].append_array(region)

	# Explicitly ensure critical positions are connected to spawn 0
	var origin: Vector2i = robot_spawns[0]
	# Carve to exit
	_carve_corridor(origin, exit_position)
	# Carve to keys
	for kp: Vector2i in key_positions:
		_carve_corridor(origin, kp)
	# Carve to all robot spawns
	for sp: Vector2i in robot_spawns:
		_carve_corridor(origin, sp)


## Carve a corridor between two points, clearing walls and filling gaps.
func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var current: Vector2i = from
	var safety: int = 0
	while current != to and safety < 200:
		safety += 1
		var dx: int = signi(to.x - current.x)
		var dy: int = signi(to.y - current.y)
		# Prefer the axis with the larger distance
		if absi(to.x - current.x) >= absi(to.y - current.y):
			current.x += dx
		else:
			current.y += dy

		# Stay in bounds (not on perimeter)
		if current.x < 1 or current.x >= width - 1:
			continue
		if current.y < 1 or current.y >= height - 1:
			continue

		# Clear wall if blocking
		if wall_grid[current.y][current.x] == WallCell.WALL:
			wall_grid[current.y][current.x] = WallCell.EMPTY
		# Ensure solid floor
		if floor_grid[current.y][current.x] == FloorCell.GAP:
			floor_grid[current.y][current.x] = FloorCell.SOLID

