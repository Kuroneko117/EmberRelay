extends RefCounted
const IDLE = preload("res://assets/art/player-idle.png")
const RUN = preload("res://assets/art/player-run.png")
const JUMP = preload("res://assets/art/player-jump.png")
const HURT = preload("res://assets/art/player-hurt.png")
const SHOOT = preload("res://assets/art/player-run-shoot.png")
const STAND = preload("res://assets/art/player-stand.png")

static func draw_pose(n: CanvasItem, animation: String, frame: int, tint: Color=Color.WHITE) -> void:
	var tex: Texture2D = IDLE
	match animation:
		"run": tex = RUN
		"jump": tex = JUMP
		"hurt": tex = HURT
		"shoot": tex = SHOOT
		"stand": tex = STAND
	frame = posmod(frame,int(tex.get_width()/80))
	n.draw_texture_rect_region(tex,Rect2(-40,-64,80,80),Rect2(frame*80,0,80,80),tint)

