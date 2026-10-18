extends Control
## A connected six-stop route chart using the game's own industrial city layers.
const ART = preload("res://scripts/art.gd")
const FONT = preload("res://assets/ui_font.ttc")
const POINTS = [Vector2(0.17,0.29),Vector2(0.50,0.23),Vector2(0.83,0.29),Vector2(0.83,0.76),Vector2(0.50,0.82),Vector2(0.17,0.76)]
var game: Node
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0c1e28"))
	for i: int in range(3):
		draw_texture_rect(ART.CITY,Rect2(i*272,0,272,150),false,Color(0.36,0.49,0.52,0.16))
		draw_texture_rect(preload("res://assets/art/water-near-buildings-bg.png"),Rect2(i*493,size.y*0.52,493,209),false,Color(0.30,0.52,0.56,0.16))
	var shore: PackedVector2Array = PackedVector2Array()
	for i: int in range(19): shore.append(Vector2(i*size.x/18,size.y*(0.51+sin(i*0.82)*0.025)))
	draw_polyline(shore,Color("2a4c57"),2)
	for i: int in range(1,6):
		var a: Vector2 = POINTS[i-1]*size
		var b: Vector2 = POINTS[i]*size
		var unlocked: bool = i<3 or game.campaign.unlocked>=1
		var col: Color = Color("af956c") if unlocked else Color("354c57")
		draw_line(a,b,Color("08151d"),7)
		draw_dashed_line(a,b,col,2,7)
	for i: int in range(6):
		var p: Vector2 = POINTS[i]*size
		var current: bool = is_instance_valid(game.player) and game.chapter==i
		var col: Color = Color("ecb371") if current else Color("83b5b1") if game.campaign.visited.has(i) else Color("536b73")
		draw_circle(p,23,Color(col,0.06))
		draw_arc(p,23,0,TAU,40,Color(col,0.55),1)
		if current: draw_arc(p,26,-2.9,-0.3,24,col,2)
		var text: String = "当前位置" if current else "首领已击败" if i%3==2 and game.campaign.completed.has(i/3) else "已探索" if game.campaign.visited.has(i) else "首领 · 未挑战" if i%3==2 and i/3<=game.campaign.unlocked else "未探索" if i/3<=game.campaign.unlocked else "航线未接通"
		var width: float = FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
		draw_string(FONT,p+Vector2(-width/2,29),text,HORIZONTAL_ALIGNMENT_LEFT,-1,8,col)
	draw_rect(Rect2(Vector2.ZERO,size),Color("39545e"),false,1)
