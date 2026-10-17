extends Control
const FONT = preload("res://assets/ui_font.ttc")
var game: Node
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1a23"))
	for x: int in range(0,int(size.x),18): draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.3,0.5,0.5,0.08),1)
	var scale_x: float = (size.x-24)/game.level_width
	for floor_rect: Rect2 in game.platforms:
		var x: float = 12+maxf(0,floor_rect.position.x)*scale_x
		var y: float = 30+(floor_rect.position.y-130)*0.35
		draw_rect(Rect2(x,y,minf(size.x-x-12,floor_rect.size.x*scale_x),3),Color("618c8b"))
	for point: float in game.campaign.checkpoints():
		var p: Vector2 = Vector2(12+point*scale_x,88)
		draw_line(p-Vector2(0,6),p+Vector2(0,6),Color("83c8bc"),3)
	for chest: Dictionary in game.director.chests:
		if not chest.open: draw_rect(Rect2(12+chest.pos.x*scale_x,23+(chest.pos.y-130)*0.35,4,4),Color("ecb371"))
	for device: Dictionary in game.guide.devices():
		var p: Vector2 = Vector2(12+device.pos.x*scale_x,22+(device.pos.y-130)*0.35)
		var col: Color = Color("83c8bc") if device.on else Color("ecb371")
		draw_line(p-Vector2(0,7),p-Vector2(0,20),col,1)
		draw_rect(Rect2(p-Vector2(8,33),Vector2(17,14)),Color("102c35"))
		draw_rect(Rect2(p-Vector2(8,33),Vector2(17,14)),col,false,1)
		draw_string(FONT,p-Vector2(3,22),device.id,HORIZONTAL_ALIGNMENT_LEFT,-1,9,col)
		if device.on: draw_line(p-Vector2(4,3),p+Vector2(4,-3),col,2)
	var objective: Dictionary = game.guide.current()
	if not objective.is_empty() and objective.kind!="combat":
		var p: Vector2 = Vector2(12+objective.pos.x*scale_x,22+(objective.pos.y-130)*0.35)
		var diamond: PackedVector2Array = PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0),p+Vector2(0,-7)])
		draw_polyline(diamond,Color("ecb371"),1)
	draw_circle(Vector2(12+game.player.position.x*scale_x,22+(game.player.position.y-130)*0.35),4,Color("f9dfae"))
	draw_line(Vector2(size.x-14,78),Vector2(size.x-14,92),Color("f1b17e"),4)
