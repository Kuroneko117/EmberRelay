extends RefCounted
## Drawn from the character explicitly approved by Akagi, normalized in Aseprite.
const IDLE = preload("res://assets/art/courier-approved/idle.png")
const RUN = preload("res://assets/art/courier-approved/run.png")
const ATTACK = preload("res://assets/art/courier-approved/attack.png")
const ATTACK2 = preload("res://assets/art/courier-approved/attack2.png")
const ATTACK3 = preload("res://assets/art/courier-approved/attack3.png")
const LAND = preload("res://assets/art/courier-approved/land.png")
const UTILITY = preload("res://assets/art/courier-approved/utility.png")
const CELL: Vector2 = Vector2(128,96)
const PIVOT: Vector2 = Vector2(56,80)
# Utility frame7 outer weapon edge (100,45), normalized pivot(56,80).
const PULSE_MUZZLE: Vector2 = Vector2(44,-35)
const UPPER_CELL: Vector2 = Vector2(128,104)
const UPPER_PIVOT: Vector2 = Vector2(56,88)
const HEAVY_CELL: Vector2 = Vector2(128,112)
const HEAVY_PIVOT: Vector2 = Vector2(56,96)
const UTILITY_POSES: Dictionary = {
	"rise":0,"apex":1,"fall":2,"dash":3,
	"parry":4,"hurt":5,"death":6,"pulse":7,
	"shoot":7,"stand":7,
}

static func frame_count(animation: String) -> int:
	if animation in ["idle","land"]: return 4
	if animation in ["run","attack","attack2"]: return 6
	if animation=="attack3": return 8
	return 1

static func attack_frame(elapsed: float,duration: float,combo: int=1) -> int:
	var contact: float = 0.075 if combo==3 else 0.045
	var windup: int = 3 if combo==3 else 2
	var total: int = 8 if combo==3 else 6
	if elapsed+0.00001<contact:
		return clampi(int((elapsed+0.00001)/contact*windup),0,windup-1)
	return clampi(windup+int((elapsed-contact)/maxf(0.001,duration-contact)*(total-windup)),windup,total-1)

static func draw_pose(n: CanvasItem,animation: String,frame: int,tint: Color=Color.WHITE) -> void:
	var texture: Texture2D = IDLE
	var index: int = posmod(frame,4)
	var cell: Vector2 = CELL
	var pivot: Vector2 = PIVOT
	match animation:
		"run":
			texture = RUN
			index = posmod(frame,6)
		"attack":
			texture = ATTACK
			index = clampi(frame,0,5)
		"attack2":
			texture = ATTACK2
			index = clampi(frame,0,5)
			cell = UPPER_CELL
			pivot = UPPER_PIVOT
		"attack3":
			texture = ATTACK3
			index = clampi(frame,0,7)
			cell = HEAVY_CELL
			pivot = HEAVY_PIVOT
		"land":
			texture = LAND
			index = clampi(frame,0,3)
		"jump":
			texture = UTILITY
			index = 0 if frame<2 else 1 if frame<4 else 2
		_:
			if UTILITY_POSES.has(animation):
				texture = UTILITY
				index = UTILITY_POSES[animation]
	n.draw_texture_rect_region(texture,Rect2(-pivot,cell),Rect2(Vector2(index*cell.x,0),cell),tint)
