## Instruction resource class for GOTO
## Defines a single instruction that can be placed in a robot's buffer.
class_name Instruction
extends Resource

enum Type {
	MOVE_FORWARD,
	MOVE_BACKWARD,
	TURN_LEFT,
	TURN_RIGHT,
	U_TURN,
	STRAFE_LEFT,
	STRAFE_RIGHT,
	SHOVE_FORWARD,
	SHOVE_ALL,
	FIRE_LASER,
	SPRINT,
	WAIT,
	# Rare
	JUMP,
	SHIELD,
	FIRE_SHOTGUN,
	SELF_DESTRUCT,
	EMP,
	OVERCLOCK,
	REPAIR,
	TELEPORT,
}

enum Rarity {
	COMMON,
	RARE,
}

@export var instruction_name: String = ""
@export var type: Type = Type.WAIT
@export var rarity: Rarity = Rarity.COMMON
@export var icon_color: Color = Color.WHITE
@export var description: String = ""


func _to_string() -> String:
	return instruction_name
