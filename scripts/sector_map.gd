extends Control
## Readable floor plan with a route overview, zoom, drag and keyboard panning.
const FONT = preload("res://assets/ui_font.ttc")
signal view_changed
var game: Node
var center_x: float = 320
var view_width: float = 1280
var dragging: bool = false
func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	resized.connect(queue_redraw)
	center_on_player()
func center_on_player() -> void:
	view_width = minf(game.level_width,1280)
	center_x = game.player.position.x
	_clamp_view()
func overview() -> void:
	view_width = game.level_width
	center_x = game.level_width/2
	_clamp_view()
func zoom_by(factor: float) -> void:
	view_width = clampf(view_width*factor,600,game.level_width)
	_clamp_view()
func pan(direction: float) -> void:
	center_x += direction*view_width*0.22
	_clamp_view()
func _clamp_view() -> void:
	center_x = clampf(center_x,view_width/2,game.level_width-view_width/2)
	queue_redraw()
	view_changed.emit()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(0.75); accept_event()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1.33); accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed and event.position.y<24:
				center_x = (event.position.x-12)/(size.x-24)*game.level_width
				_clamp_view()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		center_x -= event.relative.x/(size.x-24)*view_width
		_clamp_view()
		accept_event()
func point(pos: Vector2) -> Vector2:
	return Vector2(12+(pos.x-(center_x-view_width/2))*(size.x-24)/view_width,37+(pos.y-130)*(size.y-62)/180)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1c26"))
	var left: float = center_x-view_width/2
	var sx: float = (size.x-24)/view_width
	for x: int in range(int(left/160)*160,int(left+view_width)+160,160):
		var px: float = point(Vector2(x,130)).x
		draw_line(Vector2(px,24),Vector2(px,size.y),Color(0.35,0.55,0.58,0.08),1)
	# A full-route strip keeps the zoomed floor plan anchored in the larger area.
	draw_rect(Rect2(0,0,size.x,24),Color("152c36"))
	draw_line(Vector2(12,12),Vector2(size.x-12,12),Color("42616a"),2)
	var overview_scale: float = (size.x-24)/game.level_width
	draw_rect(Rect2(12+left*overview_scale,5,view_width*overview_scale,14),Color(0.51,0.78,0.73,0.12))
	draw_rect(Rect2(12+left*overview_scale,5,view_width*overview_scale,14),Color("638d90"),false,1)
	draw_circle(Vector2(12+game.player.position.x*overview_scale,12),3,Color("f9dfae"))
	for i: int in range(game.director.arenas.size()):
		var arena: Dictionary = game.director.arenas[i]
		var start: Vector2 = point(Vector2(arena.left,300))
		var width: float = (arena.right-arena.left)*sx
		var col: Color = Color("4b8b80") if arena.done else Color("9b6758")
		draw_rect(Rect2(start.x,27,width,size.y-27),Color(col,0.065))
		draw_string(FONT,Vector2(start.x+4,size.y-5),"封锁 %d · %s"%[i+1,"解除" if arena.done else "未解除"],HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(col,0.85))
	for platform: Rect2 in game.platforms:
		var p: Vector2 = point(platform.position)
		var width: float = platform.size.x*sx
		if platform.size.y>30:
			draw_rect(Rect2(p,Vector2(width,size.y-p.y)),Color("162e38"))
			draw_rect(Rect2(p,Vector2(width,4)),Color("688c91"))
		else:
			draw_rect(Rect2(p,Vector2(width,3)),Color("9abbb4"))
			draw_line(p+Vector2(0,4),p+Vector2(width,4),Color("344f58"),1)
	for landmark: Dictionary in game.campaign.landmarks():
		var p: Vector2 = point(Vector2(landmark.x,130))
		if p.x>20 and p.x<size.x-70: draw_string(FONT,p+Vector2(-20,-3),landmark.name,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("6d9296"))
	for checkpoint: float in game.campaign.checkpoints():
		var p: Vector2 = point(Vector2(checkpoint,300))
		draw_rect(Rect2(p-Vector2(3,9),Vector2(6,9)),Color("83c8bc"))
	for chest: Dictionary in game.director.chests:
		if not chest.open:
			var p: Vector2 = point(chest.pos)-Vector2(3,8)
			draw_rect(Rect2(p,Vector2(6,5)),Color("ecb371"),false,1)
	for device: Dictionary in game.guide.devices():
		var p: Vector2 = point(device.pos)
		var col: Color = Color("83c8bc") if device.on else Color("ecb371")
		draw_line(p-Vector2(0,4),p-Vector2(0,15),col,1)
		draw_rect(Rect2(p-Vector2(8,29),Vector2(17,14)),Color("102c35"))
		draw_rect(Rect2(p-Vector2(8,29),Vector2(17,14)),col,false,1)
		draw_string(FONT,p-Vector2(3,18),device.id,HORIZONTAL_ALIGNMENT_LEFT,-1,9,col)
	var objective: Dictionary = game.guide.current()
	if not objective.is_empty() and objective.kind!="combat":
		var target: Vector2 = point(objective.pos)
		var route: Array[Vector2] = game.guide.platform_route(game.player.position,objective.pos)
		for i: int in range(route.size()-1):
			draw_dashed_line(point(route[i])-Vector2(0,5),point(route[i+1])-Vector2(0,5),Color("bc995f"),1,4)
		draw_polyline(PackedVector2Array([target+Vector2(0,-6),target+Vector2(6,0),target+Vector2(0,6),target+Vector2(-6,0),target+Vector2(0,-6)]),Color("ecb371"),1)
		draw_circle(Vector2(12+objective.pos.x*overview_scale,12),2,Color("ecb371"))
	var player: Vector2 = point(game.player.position)
	draw_circle(player-Vector2(0,5),4,Color("f9dfae"))
	draw_line(player-Vector2(0,4),player+Vector2(0,4),Color("f9dfae"),1)
	var gate: Vector2 = point(Vector2(game.portal_x,300))
	draw_rect(Rect2(gate-Vector2(3,14),Vector2(6,14)),Color("83c8bc") if game.gate_open() else Color("a66d57"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("39545e"),false,1)
