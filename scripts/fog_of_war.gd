## Fog of war / visibility system for GOTO.
## Hides voxels and enemies that are not in line of sight from robots.
extends Node3D

const VISIBILITY_RANGE: int = 15

var _level: LevelGenerator
var _robots: Array[Robot] = []
var _visible_tiles: Dictionary = {}  # Vector2i -> bool


func setup(level: LevelGenerator, robots: Array[Robot]) -> void:
	_level = level
	_robots = robots


func update_visibility() -> void:
	_visible_tiles.clear()

	for robot: Robot in _robots:
		if not robot.is_alive:
			continue
		_cast_visibility_from(robot.grid_pos)


func _cast_visibility_from(origin: Vector2i) -> void:
	# Simple raycasting in all directions
	_visible_tiles[origin] = true

	for angle_step: int in range(360):
		var angle_rad: float = deg_to_rad(angle_step)
		var dx: float = cos(angle_rad)
		var dy: float = sin(angle_rad)

		for dist: int in range(1, VISIBILITY_RANGE + 1):
			var check_x: int = origin.x + roundi(dx * dist)
			var check_y: int = origin.y + roundi(dy * dist)
			var tile := Vector2i(check_x, check_y)

			if check_x < 0 or check_x >= _level.width:
				break
			if check_y < 0 or check_y >= _level.height:
				break

			_visible_tiles[tile] = true

			# Stop at walls
			if _level.wall_grid[check_y][check_x] == LevelGenerator.WallCell.WALL:
				break
			if _level.wall_grid[check_y][check_x] == LevelGenerator.WallCell.DOOR_LOCKED:
				break


func is_tile_visible(pos: Vector2i) -> bool:
	return _visible_tiles.has(pos)


## Apply visibility to level renderer children and enemies.
func apply_visibility(level_renderer: Node3D, enemies: Array[Enemy]) -> void:
	# For now, just hide/show enemies based on visibility
	for enemy: Enemy in enemies:
		if enemy.is_alive:
			enemy.visible = is_tile_visible(enemy.grid_pos)
