## HUD controller for GOTO.
## Manages the bottom-bar with robot panels, instruction pool, and turn progress.
extends CanvasLayer

# References set by main scene
var _game_manager: Node  # GameManager autoload

# UI containers
var _root_panel: PanelContainer
var _turn_progress_bar: HBoxContainer  # Top bar: turn step squares
var _instruction_pool_container: HBoxContainer
var _robot_panels: Array[VBoxContainer] = []
var _robot_buffer_slots: Array[Array] = []  # [robot_idx][slot_idx] = Button
var _countdown_label: Label
var _state_label: Label
var _start_button: Button
var _message_label: Label

# Instruction pool buttons
var _pool_buttons: Array[Button] = []

# Drag state
var _dragging_instruction: Instruction = null
var _dragging_from_pool: int = -1
var _dragging_from_robot: int = -1
var _dragging_from_slot: int = -1

# Turn progress
var _turn_squares: Array[Panel] = []

# Colors
const BG_COLOR := Color(0.1, 0.1, 0.15, 0.9)
const PANEL_COLOR := Color(0.15, 0.15, 0.2, 0.95)
const SLOT_EMPTY := Color(0.2, 0.2, 0.25)
const SLOT_DISABLED := Color(0.3, 0.05, 0.05)
const TURN_INACTIVE := Color(0.2, 0.2, 0.25)
const TURN_COMPLETE := Color(0.1, 0.8, 0.3)
const TURN_CURRENT := Color(1.0, 0.9, 0.1)


func _ready() -> void:
	_game_manager = GameManager
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# === TURN PROGRESS BAR (top of screen) ===
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_left", 200)
	top_margin.add_theme_constant_override("margin_right", 200)
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(top_margin)

	var top_center := CenterContainer.new()
	top_margin.add_child(top_center)

	_turn_progress_bar = HBoxContainer.new()
	_turn_progress_bar.add_theme_constant_override("separation", 4)
	_turn_progress_bar.visible = false
	top_center.add_child(_turn_progress_bar)

	# === STATE / MESSAGE LABELS ===
	var state_margin := MarginContainer.new()
	state_margin.add_theme_constant_override("margin_top", 40)
	state_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(state_margin)

	var state_center := CenterContainer.new()
	state_margin.add_child(state_center)

	_state_label = Label.new()
	_state_label.text = "PLANNING PHASE"
	_state_label.add_theme_font_size_override("font_size", 20)
	_state_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	state_center.add_child(_state_label)

	# === MESSAGE LABEL (center screen for victory/game over) ===
	var msg_container := CenterContainer.new()
	msg_container.set_anchors_preset(Control.PRESET_CENTER)
	add_child(msg_container)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_font_size_override("font_size", 48)
	_message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	_message_label.visible = false
	msg_container.add_child(_message_label)

	# === BOTTOM BAR ===
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_vbox.add_theme_constant_override("separation", 4)
	add_child(bottom_vbox)

	# Spacer to push content to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_vbox.add_child(spacer)

	# Countdown / Start button row
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	bottom_vbox.add_child(button_row)

	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.add_theme_font_size_override("font_size", 24)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	button_row.add_child(_countdown_label)

	_start_button = Button.new()
	_start_button.text = "START ROUND [Space]"
	_start_button.custom_minimum_size = Vector2(200, 36)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	# Instruction pool row
	var pool_panel := PanelContainer.new()
	var pool_style := StyleBoxFlat.new()
	pool_style.bg_color = PANEL_COLOR
	pool_style.corner_radius_top_left = 4
	pool_style.corner_radius_top_right = 4
	pool_style.content_margin_left = 8
	pool_style.content_margin_right = 8
	pool_style.content_margin_top = 4
	pool_style.content_margin_bottom = 4
	pool_panel.add_theme_stylebox_override("panel", pool_style)
	bottom_vbox.add_child(pool_panel)

	var pool_vbox := VBoxContainer.new()
	pool_panel.add_child(pool_vbox)

	var pool_label := Label.new()
	pool_label.text = "INSTRUCTION POOL"
	pool_label.add_theme_font_size_override("font_size", 12)
	pool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	pool_vbox.add_child(pool_label)

	var pool_scroll := ScrollContainer.new()
	pool_scroll.custom_minimum_size = Vector2(0, 50)
	pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pool_vbox.add_child(pool_scroll)

	_instruction_pool_container = HBoxContainer.new()
	_instruction_pool_container.add_theme_constant_override("separation", 4)
	pool_scroll.add_child(_instruction_pool_container)

	# Robot panels row
	var robot_row_panel := PanelContainer.new()
	var robot_row_style := StyleBoxFlat.new()
	robot_row_style.bg_color = BG_COLOR
	robot_row_style.content_margin_left = 8
	robot_row_style.content_margin_right = 8
	robot_row_style.content_margin_top = 4
	robot_row_style.content_margin_bottom = 8
	robot_row_panel.add_theme_stylebox_override("panel", robot_row_style)
	bottom_vbox.add_child(robot_row_panel)

	var robot_row := HBoxContainer.new()
	robot_row.add_theme_constant_override("separation", 8)
	robot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	robot_row_panel.add_child(robot_row)

	# Create 4 robot panels
	for i: int in range(4):
		var panel := _create_robot_panel(i)
		robot_row.add_child(panel)


func _create_robot_panel(robot_id: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(180, 0)
	panel.add_theme_constant_override("separation", 2)

	var panel_bg := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.18)
	bg_style.border_color = Robot.ROBOT_COLORS[robot_id] * 0.6
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 1
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.content_margin_left = 6
	bg_style.content_margin_right = 6
	bg_style.content_margin_top = 4
	bg_style.content_margin_bottom = 4
	panel_bg.add_theme_stylebox_override("panel", bg_style)
	panel.add_child(panel_bg)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	panel_bg.add_child(inner_vbox)

	# Robot header
	var header := Label.new()
	header.text = "ROBOT %d" % (robot_id + 1)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Robot.ROBOT_COLORS[robot_id])
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(header)

	# Instruction buffer slots
	var slots_container := HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 3)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_child(slots_container)

	var slot_buttons: Array = []
	for slot_idx: int in range(Robot.MAX_HP):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(30, 30)
		slot_btn.text = ""
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = SLOT_EMPTY
		slot_style.corner_radius_top_left = 3
		slot_style.corner_radius_top_right = 3
		slot_style.corner_radius_bottom_left = 3
		slot_style.corner_radius_bottom_right = 3
		slot_btn.add_theme_stylebox_override("normal", slot_style)
		slot_btn.pressed.connect(_on_buffer_slot_pressed.bind(robot_id, slot_idx))
		slots_container.add_child(slot_btn)
		slot_buttons.append(slot_btn)

	_robot_buffer_slots.append(slot_buttons)
	_robot_panels.append(panel)
	return panel


func _connect_signals() -> void:
	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.instruction_pool_updated.connect(_on_pool_updated)
	_game_manager.turn_order_updated.connect(_on_turn_order_updated)
	_game_manager.turn_engine.turn_started.connect(_on_turn_step)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLANNING:
			_state_label.text = "PLANNING PHASE"
			_start_button.visible = true
			_turn_progress_bar.visible = false
			_message_label.visible = false
			_countdown_label.text = ""
		GameManager.GameState.COUNTDOWN:
			_state_label.text = "COUNTDOWN"
			_start_button.text = "CANCEL"
		GameManager.GameState.EXECUTING:
			_state_label.text = "EXECUTING"
			_start_button.visible = false
			_build_turn_progress(GameManager.turn_engine.get_total_steps())
			_turn_progress_bar.visible = true
		GameManager.GameState.GAME_OVER:
			_state_label.text = "GAME OVER"
			_message_label.text = "ALL ROBOTS DESTROYED"
			_message_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			_message_label.visible = true
		GameManager.GameState.VICTORY:
			_state_label.text = "VICTORY!"
			_message_label.text = "MISSION COMPLETE"
			_message_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			_message_label.visible = true

	_refresh_all_slots()


func _on_pool_updated(pool: Array) -> void:
	# Clear existing pool buttons
	for btn: Node in _instruction_pool_container.get_children():
		btn.queue_free()
	_pool_buttons.clear()

	# Create new buttons
	for i: int in range(pool.size()):
		var instr: Instruction = pool[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 40)
		btn.text = instr.instruction_name
		btn.add_theme_font_size_override("font_size", 10)
		var style := StyleBoxFlat.new()
		style.bg_color = instr.icon_color * 0.7
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
		btn.tooltip_text = instr.description
		btn.pressed.connect(_on_pool_instruction_pressed.bind(i))
		_instruction_pool_container.add_child(btn)
		_pool_buttons.append(btn)


func _on_turn_order_updated(_order: Array) -> void:
	# Could display turn order numbers on entities
	pass


func _build_turn_progress(total_steps: int) -> void:
	# Clear existing
	for child: Node in _turn_progress_bar.get_children():
		child.queue_free()
	_turn_squares.clear()

	for i: int in range(total_steps):
		var square := Panel.new()
		square.custom_minimum_size = Vector2(24, 24)
		var style := StyleBoxFlat.new()
		style.bg_color = TURN_INACTIVE
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		square.add_theme_stylebox_override("panel", style)
		_turn_progress_bar.add_child(square)
		_turn_squares.append(square)


func _on_turn_step(entity_index: int, _total: int) -> void:
	# Update turn progress squares
	for i: int in range(_turn_squares.size()):
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		if i < entity_index:
			style.bg_color = TURN_COMPLETE
		elif i == entity_index:
			style.bg_color = TURN_CURRENT
		else:
			style.bg_color = TURN_INACTIVE
		_turn_squares[i].add_theme_stylebox_override("panel", style)


func _refresh_all_slots() -> void:
	for robot_id: int in range(4):
		if robot_id >= _game_manager.robots.size():
			continue
		var robot: Robot = _game_manager.robots[robot_id]
		for slot_idx: int in range(Robot.MAX_HP):
			var btn: Button = _robot_buffer_slots[robot_id][slot_idx]
			if slot_idx >= robot.hp:
				# Slot destroyed by damage
				btn.text = "X"
				btn.disabled = true
				var style := StyleBoxFlat.new()
				style.bg_color = SLOT_DISABLED
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_left = 3
				style.corner_radius_bottom_right = 3
				btn.add_theme_stylebox_override("normal", style)
			elif slot_idx < robot.instruction_buffer.size() and robot.instruction_buffer[slot_idx] != null:
				var instr: Instruction = robot.instruction_buffer[slot_idx]
				btn.text = instr.instruction_name.substr(0, 4)
				btn.tooltip_text = instr.instruction_name
				btn.disabled = false
				var style := StyleBoxFlat.new()
				style.bg_color = instr.icon_color * 0.6
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_left = 3
				style.corner_radius_bottom_right = 3
				btn.add_theme_stylebox_override("normal", style)
			else:
				btn.text = ""
				btn.tooltip_text = "Empty slot"
				btn.disabled = false
				var style := StyleBoxFlat.new()
				style.bg_color = SLOT_EMPTY
				style.corner_radius_top_left = 3
				style.corner_radius_top_right = 3
				style.corner_radius_bottom_left = 3
				style.corner_radius_bottom_right = 3
				btn.add_theme_stylebox_override("normal", style)


## Simple click-to-assign: clicking pool instruction assigns to first robot with space
var _selected_pool_index: int = -1

func _on_pool_instruction_pressed(pool_index: int) -> void:
	if _game_manager.current_state != GameManager.GameState.PLANNING:
		return
	# Try to assign to each robot in order
	for robot_id: int in range(4):
		if _game_manager.assign_instruction(pool_index, robot_id):
			_refresh_all_slots()
			return


func _on_buffer_slot_pressed(robot_id: int, slot_idx: int) -> void:
	if _game_manager.current_state != GameManager.GameState.PLANNING:
		return
	if _game_manager.return_instruction(robot_id, slot_idx):
		_refresh_all_slots()


func _on_start_pressed() -> void:
	if _game_manager.current_state == GameManager.GameState.PLANNING:
		_game_manager.start_countdown()
	elif _game_manager.current_state == GameManager.GameState.COUNTDOWN:
		_game_manager.cancel_countdown()


func _process(_delta: float) -> void:
	if _game_manager.current_state == GameManager.GameState.COUNTDOWN:
		var time_left: float = _game_manager.get_countdown_time()
		_countdown_label.text = "Starting in %d..." % ceili(time_left)

	# Space to start round
	if Input.is_action_just_pressed("start_round"):
		_on_start_pressed()
