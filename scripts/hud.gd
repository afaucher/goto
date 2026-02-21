## HUD controller for GOTO.
## Manages the bottom-bar with robot panels, instruction pool, and turn progress.
extends CanvasLayer

# References set by main scene
var _game_manager: Node  # GameManager autoload

# UI containers
var _turn_progress_bar: HBoxContainer
var _instruction_pool_container: HBoxContainer
var _robot_panels: Array[VBoxContainer] = []
var _robot_buffer_slots: Array[Array] = []  # [robot_idx][slot_idx] = Button
var _countdown_label: Label
var _state_label: Label
var _start_button: Button
var _message_label: Label

# Mission objectives
var _obj_key_label: Label
var _obj_door_label: Label
var _obj_exit_label: Label

# Instruction pool buttons
var _pool_buttons: Array[Button] = []

# Turn progress
var _turn_squares: Array[Panel] = []

# Selected robot for instruction assignment
var _selected_robot: int = 0

# Colors
const BG_COLOR := Color(0.1, 0.1, 0.15, 0.92)
const PANEL_COLOR := Color(0.15, 0.15, 0.2, 0.95)
const SLOT_EMPTY := Color(0.25, 0.25, 0.3)
const SLOT_DISABLED := Color(0.35, 0.08, 0.08)
const TURN_INACTIVE := Color(0.2, 0.2, 0.25)
const TURN_COMPLETE := Color(0.1, 0.8, 0.3)
const TURN_CURRENT := Color(1.0, 0.9, 0.1)


func _ready() -> void:
	_game_manager = GameManager
	_build_ui()
	# Defer signal connection so GameManager is fully initialized
	call_deferred("_connect_signals")


func _build_ui() -> void:
	# === FULL SCREEN CONTAINER ===
	# Use a top-level Control that fills the entire screen
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# === TOP SECTION: Turn progress + State label ===
	var top_vbox := VBoxContainer.new()
	top_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_vbox.offset_bottom = 80
	top_vbox.add_theme_constant_override("separation", 4)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_vbox)

	# State label
	_state_label = Label.new()
	_state_label.text = "PLANNING PHASE"
	_state_label.add_theme_font_size_override("font_size", 22)
	_state_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(_state_label)

	# Turn progress bar container
	var progress_center := CenterContainer.new()
	progress_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(progress_center)

	_turn_progress_bar = HBoxContainer.new()
	_turn_progress_bar.add_theme_constant_override("separation", 3)
	_turn_progress_bar.visible = false
	_turn_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_center.add_child(_turn_progress_bar)

	# === TOP RIGHT: Mission Objectives ===
	var obj_panel := PanelContainer.new()
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	obj_style.border_color = Color(0.3, 0.3, 0.4)
	obj_style.border_width_top = 1
	obj_style.border_width_bottom = 1
	obj_style.border_width_left = 1
	obj_style.border_width_right = 1
	obj_style.corner_radius_top_left = 6
	obj_style.corner_radius_top_right = 6
	obj_style.corner_radius_bottom_left = 6
	obj_style.corner_radius_bottom_right = 6
	obj_style.content_margin_left = 12
	obj_style.content_margin_right = 12
	obj_style.content_margin_top = 8
	obj_style.content_margin_bottom = 8
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	obj_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	obj_panel.offset_left = -220
	obj_panel.offset_right = -12
	obj_panel.offset_top = 12
	obj_panel.offset_bottom = 140
	root.add_child(obj_panel)

	var obj_vbox := VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 4)
	obj_panel.add_child(obj_vbox)

	var obj_title := Label.new()
	obj_title.text = "MISSION OBJECTIVES"
	obj_title.add_theme_font_size_override("font_size", 12)
	obj_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	obj_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj_vbox.add_child(obj_title)

	var sep := HSeparator.new()
	obj_vbox.add_child(sep)

	_obj_key_label = Label.new()
	_obj_key_label.text = "○  Find the key"
	_obj_key_label.add_theme_font_size_override("font_size", 13)
	_obj_key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	obj_vbox.add_child(_obj_key_label)

	_obj_door_label = Label.new()
	_obj_door_label.text = "○  Unlock the door"
	_obj_door_label.add_theme_font_size_override("font_size", 13)
	_obj_door_label.add_theme_color_override("font_color", Color(0.6, 0.35, 0.15))
	obj_vbox.add_child(_obj_door_label)

	_obj_exit_label = Label.new()
	_obj_exit_label.text = "○  Reach the exit"
	_obj_exit_label.add_theme_font_size_override("font_size", 13)
	_obj_exit_label.add_theme_color_override("font_color", Color(0.1, 0.9, 0.3))
	obj_vbox.add_child(_obj_exit_label)

	# === CENTER: Victory/Game Over message ===
	var msg_center := CenterContainer.new()
	msg_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	msg_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_center)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.add_theme_font_size_override("font_size", 52)
	_message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
	_message_label.visible = false
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_center.add_child(_message_label)

	# === BOTTOM SECTION ===
	var bottom_panel := PanelContainer.new()
	var bp_style := StyleBoxFlat.new()
	bp_style.bg_color = BG_COLOR
	bp_style.content_margin_left = 12
	bp_style.content_margin_right = 12
	bp_style.content_margin_top = 8
	bp_style.content_margin_bottom = 8
	bottom_panel.add_theme_stylebox_override("panel", bp_style)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Explicit height from bottom
	bottom_panel.offset_top = -240
	bottom_panel.offset_bottom = 0
	root.add_child(bottom_panel)

	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 6)
	bottom_panel.add_child(bottom_vbox)

	# Row 1: Start button + countdown
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	bottom_vbox.add_child(button_row)

	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.add_theme_font_size_override("font_size", 22)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	button_row.add_child(_countdown_label)

	_start_button = Button.new()
	_start_button.text = "  START ROUND [Space]  "
	_start_button.custom_minimum_size = Vector2(220, 36)
	_start_button.add_theme_font_size_override("font_size", 14)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	# Row 2: Instruction pool
	var pool_section := VBoxContainer.new()
	pool_section.add_theme_constant_override("separation", 2)
	bottom_vbox.add_child(pool_section)

	var pool_header := HBoxContainer.new()
	pool_header.add_theme_constant_override("separation", 8)
	pool_section.add_child(pool_header)

	var pool_label := Label.new()
	pool_label.text = "INSTRUCTION POOL"
	pool_label.add_theme_font_size_override("font_size", 11)
	pool_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	pool_header.add_child(pool_label)

	var pool_hint := Label.new()
	pool_hint.text = "(click to assign to selected robot)"
	pool_hint.add_theme_font_size_override("font_size", 10)
	pool_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	pool_header.add_child(pool_hint)

	var pool_panel := PanelContainer.new()
	var pool_style := StyleBoxFlat.new()
	pool_style.bg_color = Color(0.12, 0.12, 0.16, 0.8)
	pool_style.corner_radius_top_left = 4
	pool_style.corner_radius_top_right = 4
	pool_style.corner_radius_bottom_left = 4
	pool_style.corner_radius_bottom_right = 4
	pool_style.content_margin_left = 6
	pool_style.content_margin_right = 6
	pool_style.content_margin_top = 4
	pool_style.content_margin_bottom = 4
	pool_panel.add_theme_stylebox_override("panel", pool_style)
	pool_panel.custom_minimum_size = Vector2(0, 48)
	pool_section.add_child(pool_panel)

	var pool_scroll := ScrollContainer.new()
	pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pool_panel.add_child(pool_scroll)

	_instruction_pool_container = HBoxContainer.new()
	_instruction_pool_container.add_theme_constant_override("separation", 4)
	pool_scroll.add_child(_instruction_pool_container)

	# Row 3: Robot panels
	var robot_row := HBoxContainer.new()
	robot_row.add_theme_constant_override("separation", 8)
	robot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_vbox.add_child(robot_row)

	for i: int in range(4):
		var panel := _create_robot_panel(i)
		robot_row.add_child(panel)


func _create_robot_panel(robot_id: int) -> PanelContainer:
	var panel_bg := PanelContainer.new()
	panel_bg.custom_minimum_size = Vector2(200, 0)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.14)
	bg_style.border_color = Robot.ROBOT_COLORS[robot_id] * 0.7
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 1
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.content_margin_left = 8
	bg_style.content_margin_right = 8
	bg_style.content_margin_top = 6
	bg_style.content_margin_bottom = 6

	# Highlight selected robot
	if robot_id == _selected_robot:
		bg_style.bg_color = Color(0.15, 0.15, 0.22)
		bg_style.border_width_top = 3
		bg_style.border_color = Robot.ROBOT_COLORS[robot_id]

	panel_bg.add_theme_stylebox_override("panel", bg_style)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	panel_bg.add_child(inner_vbox)

	# Robot header (clickable to select)
	var header_btn := Button.new()
	header_btn.text = "ROBOT %d" % (robot_id + 1)
	header_btn.add_theme_font_size_override("font_size", 13)
	header_btn.add_theme_color_override("font_color", Robot.ROBOT_COLORS[robot_id])
	header_btn.flat = true
	header_btn.pressed.connect(_on_robot_header_pressed.bind(robot_id))
	inner_vbox.add_child(header_btn)

	# HP indicator
	var hp_label := Label.new()
	if robot_id < _game_manager.robots.size():
		var robot: Robot = _game_manager.robots[robot_id]
		var hearts: String = ""
		for _h: int in range(robot.hp):
			hearts += "♥"
		for _h: int in range(Robot.MAX_HP - robot.hp):
			hearts += "♡"
		hp_label.text = hearts
	else:
		hp_label.text = "♥♥♥♥♥"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(hp_label)

	# Instruction buffer slots
	var slots_container := HBoxContainer.new()
	slots_container.add_theme_constant_override("separation", 4)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_child(slots_container)

	var slot_buttons: Array = []
	for slot_idx: int in range(Robot.MAX_HP):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(34, 34)
		slot_btn.text = ""
		slot_btn.add_theme_font_size_override("font_size", 8)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = SLOT_EMPTY
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot_btn.add_theme_stylebox_override("normal", slot_style)
		slot_btn.pressed.connect(_on_buffer_slot_pressed.bind(robot_id, slot_idx))
		slot_btn.tooltip_text = "Slot %d" % (slot_idx + 1)
		slots_container.add_child(slot_btn)
		slot_buttons.append(slot_btn)

	_robot_buffer_slots.append(slot_buttons)
	_robot_panels.append(inner_vbox)
	return panel_bg


func _connect_signals() -> void:
	_game_manager.state_changed.connect(_on_state_changed)
	_game_manager.instruction_pool_updated.connect(_on_pool_updated)
	_game_manager.turn_order_updated.connect(_on_turn_order_updated)
	_game_manager.turn_engine.turn_started.connect(_on_turn_step)
	# Initial refresh — pool was generated before signals connected
	_refresh_all_slots()
	_rebuild_pool_buttons()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLANNING:
			_state_label.text = "PLANNING PHASE — Select robot, click instructions to assign"
			_start_button.visible = true
			_start_button.text = "  START ROUND [Space]  "
			_turn_progress_bar.visible = false
			_message_label.visible = false
			_countdown_label.text = ""
		GameManager.GameState.COUNTDOWN:
			_state_label.text = "COUNTDOWN..."
			_start_button.text = "  CANCEL  "
		GameManager.GameState.EXECUTING:
			_state_label.text = "EXECUTING TURNS"
			_start_button.visible = false
			_build_turn_progress(GameManager.turn_engine.get_total_steps())
			_turn_progress_bar.visible = true
		GameManager.GameState.GAME_OVER:
			_state_label.text = "GAME OVER"
			_message_label.text = "ALL ROBOTS DESTROYED"
			_message_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			_message_label.visible = true
			_start_button.visible = false
		GameManager.GameState.VICTORY:
			_state_label.text = "VICTORY!"
			_message_label.text = "MISSION COMPLETE"
			_message_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			_message_label.visible = true
			_start_button.visible = false

	_refresh_all_slots()


func _on_pool_updated(_pool: Array) -> void:
	_rebuild_pool_buttons()


func _rebuild_pool_buttons() -> void:
	# Clear existing
	for btn: Node in _instruction_pool_container.get_children():
		btn.queue_free()
	_pool_buttons.clear()

	var pool: Array = _game_manager.instruction_pool
	for i: int in range(pool.size()):
		var instr: Instruction = pool[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 40)
		btn.text = instr.instruction_name
		btn.add_theme_font_size_override("font_size", 11)

		# Color-coded background
		var style := StyleBoxFlat.new()
		style.bg_color = instr.icon_color * 0.5
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 4
		style.content_margin_right = 4
		btn.add_theme_stylebox_override("normal", style)

		# Hover style
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = instr.icon_color * 0.7
		hover_style.corner_radius_top_left = 4
		hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_left = 4
		hover_style.corner_radius_bottom_right = 4
		hover_style.content_margin_left = 4
		hover_style.content_margin_right = 4
		btn.add_theme_stylebox_override("hover", hover_style)

		# Rarity indicator
		if instr.rarity == Instruction.Rarity.RARE:
			btn.text = "★ " + instr.instruction_name
			btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))

		btn.tooltip_text = instr.description
		btn.pressed.connect(_on_pool_instruction_clicked.bind(i))
		_instruction_pool_container.add_child(btn)
		_pool_buttons.append(btn)


func _on_turn_order_updated(_order: Array) -> void:
	pass


func _build_turn_progress(total_steps: int) -> void:
	for child: Node in _turn_progress_bar.get_children():
		child.queue_free()
	_turn_squares.clear()

	for i: int in range(total_steps):
		var square := Panel.new()
		square.custom_minimum_size = Vector2(22, 22)
		var style := StyleBoxFlat.new()
		style.bg_color = TURN_INACTIVE
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		square.add_theme_stylebox_override("panel", style)
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_turn_progress_bar.add_child(square)
		_turn_squares.append(square)


func _on_turn_step(entity_index: int, _total: int) -> void:
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
			if robot_id >= _robot_buffer_slots.size():
				continue
			if slot_idx >= _robot_buffer_slots[robot_id].size():
				continue
			var btn: Button = _robot_buffer_slots[robot_id][slot_idx]
			if slot_idx >= robot.hp:
				# Slot destroyed by damage
				btn.text = "X"
				btn.disabled = true
				var style := StyleBoxFlat.new()
				style.bg_color = SLOT_DISABLED
				style.corner_radius_top_left = 4
				style.corner_radius_top_right = 4
				style.corner_radius_bottom_left = 4
				style.corner_radius_bottom_right = 4
				btn.add_theme_stylebox_override("normal", style)
			elif slot_idx < robot.instruction_buffer.size() and robot.instruction_buffer[slot_idx] != null:
				var instr: Instruction = robot.instruction_buffer[slot_idx]
				# Show abbreviated name
				var display_name: String = instr.instruction_name
				if display_name.length() > 5:
					display_name = display_name.substr(0, 5)
				btn.text = display_name
				btn.tooltip_text = instr.instruction_name + "\n" + instr.description
				btn.disabled = false
				var style := StyleBoxFlat.new()
				style.bg_color = instr.icon_color * 0.5
				style.corner_radius_top_left = 4
				style.corner_radius_top_right = 4
				style.corner_radius_bottom_left = 4
				style.corner_radius_bottom_right = 4
				btn.add_theme_stylebox_override("normal", style)
			else:
				btn.text = ""
				btn.tooltip_text = "Empty slot — click an instruction to fill"
				btn.disabled = false
				var style := StyleBoxFlat.new()
				style.bg_color = SLOT_EMPTY
				style.corner_radius_top_left = 4
				style.corner_radius_top_right = 4
				style.corner_radius_bottom_left = 4
				style.corner_radius_bottom_right = 4
				btn.add_theme_stylebox_override("normal", style)


func _on_robot_header_pressed(robot_id: int) -> void:
	_selected_robot = robot_id
	# Rebuild to update selection highlight
	# Quick visual update: just update border colors
	_update_selection_visuals()


func _update_selection_visuals() -> void:
	for i: int in range(_robot_panels.size()):
		var panel_bg: PanelContainer = _robot_panels[i].get_parent() as PanelContainer
		if panel_bg == null:
			continue
		var bg_style := StyleBoxFlat.new()
		bg_style.border_width_top = 3
		bg_style.border_width_bottom = 1
		bg_style.border_width_left = 1
		bg_style.border_width_right = 1
		bg_style.corner_radius_top_left = 6
		bg_style.corner_radius_top_right = 6
		bg_style.corner_radius_bottom_left = 4
		bg_style.corner_radius_bottom_right = 4
		bg_style.content_margin_left = 8
		bg_style.content_margin_right = 8
		bg_style.content_margin_top = 6
		bg_style.content_margin_bottom = 6

		if i == _selected_robot:
			bg_style.bg_color = Color(0.15, 0.15, 0.22)
			bg_style.border_color = Robot.ROBOT_COLORS[i]
		else:
			bg_style.bg_color = Color(0.1, 0.1, 0.14)
			bg_style.border_color = Robot.ROBOT_COLORS[i] * 0.5

		panel_bg.add_theme_stylebox_override("panel", bg_style)


func _on_pool_instruction_clicked(pool_index: int) -> void:
	if _game_manager.current_state != GameManager.GameState.PLANNING:
		return
	# Assign to selected robot
	if _game_manager.assign_instruction(pool_index, _selected_robot):
		_refresh_all_slots()
		_rebuild_pool_buttons()
		return
	# If selected robot is full, try other robots in order
	for rid: int in range(4):
		if rid == _selected_robot:
			continue
		if _game_manager.assign_instruction(pool_index, rid):
			_refresh_all_slots()
			_rebuild_pool_buttons()
			return


func _on_buffer_slot_pressed(robot_id: int, slot_idx: int) -> void:
	if _game_manager.current_state != GameManager.GameState.PLANNING:
		return
	if _game_manager.return_instruction(robot_id, slot_idx):
		_refresh_all_slots()
		_rebuild_pool_buttons()


func _on_start_pressed() -> void:
	if _game_manager.current_state == GameManager.GameState.PLANNING:
		_game_manager.start_countdown()
	elif _game_manager.current_state == GameManager.GameState.COUNTDOWN:
		_game_manager.cancel_countdown()


func _process(_delta: float) -> void:
	if _game_manager.current_state == GameManager.GameState.COUNTDOWN:
		var time_left: float = _game_manager.get_countdown_time()
		_countdown_label.text = "Starting in %d..." % ceili(time_left)

	if Input.is_action_just_pressed("start_round"):
		_on_start_pressed()

	_update_objectives()


func _update_objectives() -> void:
	# Key objective
	var has_key: bool = _game_manager._has_key
	if has_key:
		_obj_key_label.text = "✓  Key collected"
		_obj_key_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_obj_key_label.text = "○  Find the key"
		_obj_key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))

	# Door objective
	if has_key:
		_obj_door_label.text = "✓  Door unlocked"
		_obj_door_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_obj_door_label.text = "○  Unlock the door"
		_obj_door_label.add_theme_color_override("font_color", Color(0.6, 0.35, 0.15))

	# Exit objective
	if _game_manager.current_state == GameManager.GameState.VICTORY:
		_obj_exit_label.text = "✓  Exit reached!"
		_obj_exit_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_obj_exit_label.text = "○  Reach the exit"
		_obj_exit_label.add_theme_color_override("font_color", Color(0.1, 0.9, 0.3))
