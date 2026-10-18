extends Node2D
## Sparse industrial landmarks. Decoration never impersonates a walkable platform.
const ART = preload("res://scripts/art.gd")
const BUILDINGS = preload("res://assets/art/city_near.png")
const TRUCK = preload("res://assets/art/water-v-truck.png")
const TRANSPORT = preload("res://assets/art/water-v-police.png")
const ANTENNA = preload("res://assets/art/water-antenna.png")
const FACILITY = preload("res://assets/art/water-tiles.png")
var game: Node
var time: float = 0
func _process(delta: float) -> void:
	time += delta
	queue_redraw()
func _draw() -> void:
	if game.state=="menu" or not is_instance_valid(game.player): return
	var left: float = game.camera.position.x-365
	var right: float = game.camera.position.x+365
	for landmark: Dictionary in game.campaign.landmarks():
		if landmark.x<left-200 or landmark.x>right+200: continue
		_draw_landmark(Vector2(landmark.x,300),landmark.kind)
	for platform: Rect2 in game.platforms:
		if platform.size.y>30 or platform.end.x<left or platform.position.x>right: continue
		for x: float in [platform.position.x+12,platform.end.x-12]:
			draw_line(Vector2(x,platform.position.y+14),Vector2(x,platform.position.y+36),Color("263f48"),2)
			draw_line(Vector2(x,platform.position.y+34),Vector2(x+10,platform.position.y+15),Color("304c53"),1)
	_draw_gap_water(left,right)
func _building(p: Vector2,index: int) -> void:
	var source: Rect2 = [Rect2(0,8,88,96),Rect2(104,0,80,104),Rect2(190,0,82,104)][index%3]
	draw_texture_rect_region(BUILDINGS,Rect2(p-Vector2(source.size.x*0.5,source.size.y),source.size),source,Color("536e73"))
func _pipe(a: Vector2,b: Vector2) -> void:
	draw_line(a,b,Color("1b303a"),10)
	draw_line(a-Vector2(0,2),b-Vector2(0,2),Color("35515b"),6)
	draw_line(a-Vector2(0,4),b-Vector2(0,4),Color("456069"),1)
	for x: int in range(int(a.x)+14,int(b.x),64): draw_rect(Rect2(x,a.y-6,4,12),Color("40575d"))
func _draw_landmark(p: Vector2,kind: String) -> void:
	match kind:
		"station":
			_building(p,0)
			_building(p+Vector2(96,0),1)
		"depot":
			draw_texture_rect(TRANSPORT,Rect2(p-Vector2(81,60),Vector2(163,60)),false,Color("627a7b"))
			_building(p-Vector2(125,0),1)
		"pump", "conduit":
			_building(p-Vector2(45,0),1)
			_pipe(p-Vector2(148,96),p+Vector2(142,-96))
			ART.stamp(self,Rect2(176,112,48,32),Rect2(p-Vector2(168,111),Vector2(48,32)),Color("586f73"))
			draw_texture_rect_region(FACILITY,Rect2(p+Vector2(54,-64),Vector2(40,64)),Rect2(232,16,40,64),Color("536c70"))
		"forge":
			_building(p,2)
			_pipe(p-Vector2(120,117),p+Vector2(68,-117))
			for i: int in range(3):
				var y: float = fposmod(time*7+i*21,64)
				draw_rect(Rect2(p+Vector2(40+y*0.2,-118-y),Vector2(16+y*0.2,7)),Color(0.33,0.39,0.41,0.14*(1-y/64)))
		"cargo", "dock":
			draw_texture_rect(TRUCK,Rect2(p-Vector2(128,104),Vector2(257,104)),false,Color("526d75"))
		"crane":
			draw_rect(Rect2(p-Vector2(11,168),Vector2(12,168)),Color("293f4b"))
			draw_rect(Rect2(p-Vector2(11,168),Vector2(154,10)),Color("354d57"))
			draw_line(p-Vector2(4,145),p+Vector2(111,-161),Color("49606a"),1)
			draw_line(p+Vector2(128,-158),p+Vector2(128,-68),Color("547078"),1)
			ART.stamp(self,Rect2(80,0,16,16),Rect2(p+Vector2(120,-68),Vector2(16,16)),Color("65797a"))
		"pylon":
			for x: int in [-72,73]:
				draw_rect(Rect2(p+Vector2(x,-174),Vector2(7,174)),Color("293e4a"))
				draw_line(p+Vector2(x,-166),p+Vector2(x+90,-90),Color("344e5b"),2)
			_pipe(p-Vector2(150,174),p+Vector2(150,-174))
		"signal", "storm":
			draw_texture_rect(ANTENNA,Rect2(p-Vector2(11,96),Vector2(22,96)),false,Color("627f86"))
			_building(p+Vector2(89,0),2)
			if kind=="storm":
				for x: int in [-150,150]: draw_texture_rect(ANTENNA,Rect2(p+Vector2(x-11,-96),Vector2(22,96)),false,Color("4e6d79"))
func _draw_gap_water(left: float,right: float) -> void:
	for x: int in range(int(left/16)*16,int(right)+16,16):
		if x<0 or x>game.level_width: continue
		var solid: bool = false
		for platform: Rect2 in game.platforms:
			if platform.size.y>30 and x>=platform.position.x and x<=platform.end.x: solid = true; break
		if solid: continue
		var y: float = 339+roundf(sin(time*1.4+x*0.03))
		draw_rect(Rect2(x,y,16,32),Color("183c48") if game.chapter!=2 else Color("4b332d"))
		draw_line(Vector2(x+2,y),Vector2(x+11,y),Color("557d82") if game.chapter!=2 else Color("c28a59"),1)
