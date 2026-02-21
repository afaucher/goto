## Autoload singleton: database of all available instructions.
## Provides methods to create instruction instances and generate random pools.
extends Node

# Catalog of instruction definitions: [name, type, rarity, color, description]
var _catalog: Array[Dictionary] = []


func _ready() -> void:
	_build_catalog()


func _build_catalog() -> void:
	_catalog.clear()
	# Common instructions
	_add("Move Forward", Instruction.Type.MOVE_FORWARD, Instruction.Rarity.COMMON,
		Color(0.3, 0.8, 0.3), "Move 1 square in facing direction")
	_add("Move Backward", Instruction.Type.MOVE_BACKWARD, Instruction.Rarity.COMMON,
		Color(0.3, 0.7, 0.3), "Move 1 square opposite facing direction")
	_add("Turn Left", Instruction.Type.TURN_LEFT, Instruction.Rarity.COMMON,
		Color(0.3, 0.6, 0.9), "Rotate 90 degrees counter-clockwise")
	_add("Turn Right", Instruction.Type.TURN_RIGHT, Instruction.Rarity.COMMON,
		Color(0.3, 0.6, 0.9), "Rotate 90 degrees clockwise")
	_add("U-Turn", Instruction.Type.U_TURN, Instruction.Rarity.COMMON,
		Color(0.4, 0.5, 0.9), "Rotate 180 degrees")
	_add("Strafe Left", Instruction.Type.STRAFE_LEFT, Instruction.Rarity.COMMON,
		Color(0.5, 0.8, 0.5), "Slide 1 square left without turning")
	_add("Strafe Right", Instruction.Type.STRAFE_RIGHT, Instruction.Rarity.COMMON,
		Color(0.5, 0.8, 0.5), "Slide 1 square right without turning")
	_add("Shove Forward", Instruction.Type.SHOVE_FORWARD, Instruction.Rarity.COMMON,
		Color(0.9, 0.6, 0.2), "Push entity 2 squares in facing direction")
	_add("Shove All", Instruction.Type.SHOVE_ALL, Instruction.Rarity.COMMON,
		Color(0.9, 0.5, 0.1), "Push all adjacent entities 1 square outward")
	_add("Fire Laser", Instruction.Type.FIRE_LASER, Instruction.Rarity.COMMON,
		Color(1.0, 0.2, 0.2), "Shoot beam forward until hitting something")
	_add("Sprint", Instruction.Type.SPRINT, Instruction.Rarity.COMMON,
		Color(0.2, 0.9, 0.4), "Move 2 squares forward")
	_add("Wait", Instruction.Type.WAIT, Instruction.Rarity.COMMON,
		Color(0.6, 0.6, 0.6), "Do nothing this turn")
	# Rare instructions
	_add("Jump", Instruction.Type.JUMP, Instruction.Rarity.RARE,
		Color(0.0, 1.0, 0.8), "Leap 2 squares forward, skipping gaps")
	_add("Shield", Instruction.Type.SHIELD, Instruction.Rarity.RARE,
		Color(0.2, 0.5, 1.0), "Block next incoming damage until used")
	_add("Fire Shotgun", Instruction.Type.FIRE_SHOTGUN, Instruction.Rarity.RARE,
		Color(1.0, 0.4, 0.0), "Cone blast, 3 squares with spread")
	_add("Self Destruct", Instruction.Type.SELF_DESTRUCT, Instruction.Rarity.RARE,
		Color(1.0, 0.0, 0.0), "Destroy self, deal 3 damage in radius")
	_add("EMP", Instruction.Type.EMP, Instruction.Rarity.RARE,
		Color(0.6, 0.2, 1.0), "Disable adjacent enemies for 1 turn")
	_add("Overclock", Instruction.Type.OVERCLOCK, Instruction.Rarity.RARE,
		Color(1.0, 0.9, 0.0), "Execute next instruction twice")
	_add("Repair", Instruction.Type.REPAIR, Instruction.Rarity.RARE,
		Color(0.0, 1.0, 0.4), "Heal 1 HP")
	_add("Teleport", Instruction.Type.TELEPORT, Instruction.Rarity.RARE,
		Color(0.8, 0.0, 1.0), "Random valid tile within 5 squares")


func _add(p_name: String, p_type: Instruction.Type, p_rarity: Instruction.Rarity,
		p_color: Color, p_desc: String) -> void:
	_catalog.append({
		"name": p_name,
		"type": p_type,
		"rarity": p_rarity,
		"color": p_color,
		"description": p_desc,
	})


## Create a single instruction instance by type.
func create_instruction(p_type: Instruction.Type) -> Instruction:
	for entry: Dictionary in _catalog:
		if entry["type"] == p_type:
			var instr := Instruction.new()
			instr.instruction_name = entry["name"]
			instr.type = entry["type"]
			instr.rarity = entry["rarity"]
			instr.icon_color = entry["color"]
			instr.description = entry["description"]
			return instr
	push_warning("Unknown instruction type: %s" % p_type)
	return null


## Generate a random pool of instructions for a round.
## count: total instructions to generate.
## rare_chance: probability (0-1) of each instruction being rare.
func generate_pool(count: int, rare_chance: float = 0.15) -> Array[Instruction]:
	var pool: Array[Instruction] = []
	var common_types: Array[Instruction.Type] = []
	var rare_types: Array[Instruction.Type] = []

	for entry: Dictionary in _catalog:
		if entry["rarity"] == Instruction.Rarity.COMMON:
			common_types.append(entry["type"])
		else:
			rare_types.append(entry["type"])

	for i: int in range(count):
		var chosen_type: Instruction.Type
		if rare_types.size() > 0 and randf() < rare_chance:
			chosen_type = rare_types[randi() % rare_types.size()]
		else:
			chosen_type = common_types[randi() % common_types.size()]
		pool.append(create_instruction(chosen_type))

	return pool


## Get all entries for UI display.
func get_catalog() -> Array[Dictionary]:
	return _catalog.duplicate()
