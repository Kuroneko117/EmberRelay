extends RefCounted
## Transparent artwork frames the existing live city, never covers it with a full plate.
const HERO = preload("res://assets/studio/menu-motion/hero.png")
const FOREGROUND = preload("res://assets/studio/menu-motion/foreground.png")

static func draw(canvas: Node2D, time: float) -> void:
	canvas.draw_texture(FOREGROUND, Vector2.ZERO)
	canvas.draw_texture(HERO, Vector2.ZERO)
	# Rain falls in front of the foreground too; the city has its own deeper rain layer.
	for i: int in range(24):
		var rain := Vector2(fposmod(i * 83.0 - time * 24.0, 660.0) - 10.0, fposmod(i * 47.0 + time * 208.0, 360.0))
		canvas.draw_line(rain, rain + Vector2(-2, 9), Color(0.65, 0.78, 0.77, 0.16), 1)
	# Keep text still and legible while the landscape behind it continues to move.
	for i: int in range(38):
		var shade := 0.97 * (1.0 - smoothstep(244.0, 380.0, float(i * 10)))
		canvas.draw_rect(Rect2(i * 10, 0, 10, 360), Color(0.035, 0.07, 0.095, shade))
