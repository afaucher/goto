## Isometric camera controller.
## Orbits around a target position (selected robot).
## Left-click drag rotates, scroll zooms.
extends Camera3D

@export var rotate_speed: float = 0.008
@export var zoom_speed: float = 1.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0

## Pivot point the camera orbits around
var _pivot: Vector3 = Vector3.ZERO
## Current orbit angle in radians
var _orbit_angle: float = PI / 4.0
## Current zoom distance (orthographic size)
var _zoom: float = 12.0
## Camera elevation angle
var _elevation: float = 0.6  # ~35 degrees down

var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = _zoom
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	# Left-click drag to rotate
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start = mb.position
			else:
				_is_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(min_zoom, _zoom - zoom_speed)
			size = _zoom
			_update_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(max_zoom, _zoom + zoom_speed)
			size = _zoom
			_update_transform()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_dragging:
			_orbit_angle += mm.relative.x * rotate_speed
			_update_transform()


func _update_transform() -> void:
	var cam_dist: float = 20.0  # Doesn't matter much for ortho, just needs to be far enough
	var offset := Vector3(
		sin(_orbit_angle) * cam_dist,
		_elevation * cam_dist,
		cos(_orbit_angle) * cam_dist
	)
	global_position = _pivot + offset
	look_at(_pivot, Vector3.UP)


## Snap camera to focus on a world position (e.g. selected robot).
func center_on(world_pos: Vector3) -> void:
	_pivot = world_pos
	_update_transform()


## Smoothly move pivot toward a target position.
func follow_target(world_pos: Vector3, delta: float) -> void:
	_pivot = _pivot.lerp(world_pos, delta * 5.0)
	_update_transform()
