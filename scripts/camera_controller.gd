## Isometric camera controller.
## Attach to a Camera3D node.
extends Camera3D

@export var rotate_speed: float = 0.005
@export var zoom_speed: float = 1.0
@export var pan_speed: float = 0.02
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0

## Pivot point the camera orbits around
var _pivot: Vector3 = Vector3.ZERO
## Current orbit angle in radians
var _orbit_angle: float = PI / 4.0
## Current zoom distance
var _zoom_distance: float = 15.0
## Camera pitch (fixed for isometric)
var _pitch: float = -0.6  # ~35 degrees down

var _is_rotating: bool = false
var _is_panning: bool = false


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = _zoom_distance
	_update_transform()


## Use _input instead of _unhandled_input so UI doesn't eat mouse events
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = mb.pressed
			if mb.pressed:
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			if mb.pressed:
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_distance = maxf(min_zoom, _zoom_distance - zoom_speed)
			size = _zoom_distance
			_update_transform()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_distance = minf(max_zoom, _zoom_distance + zoom_speed)
			size = _zoom_distance
			_update_transform()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _is_rotating:
			_orbit_angle += mm.relative.x * rotate_speed
			_update_transform()
			get_viewport().set_input_as_handled()
		elif _is_panning:
			# Pan along the ground plane
			var right: Vector3 = global_transform.basis.x
			var forward: Vector3 = Vector3(-sin(_orbit_angle), 0, -cos(_orbit_angle))
			_pivot += right * mm.relative.x * pan_speed * (_zoom_distance / 15.0)
			_pivot += forward * mm.relative.y * pan_speed * (_zoom_distance / 15.0)
			_update_transform()
			get_viewport().set_input_as_handled()


func _update_transform() -> void:
	var offset := Vector3(
		sin(_orbit_angle) * _zoom_distance,
		-_pitch * _zoom_distance,
		cos(_orbit_angle) * _zoom_distance
	)
	global_position = _pivot + offset
	look_at(_pivot, Vector3.UP)


## Center the camera on a grid position.
func center_on(world_pos: Vector3) -> void:
	_pivot = world_pos
	_update_transform()
