extends Node2D
## Deterministic, layered pixel scenery: every structure has a silhouette and material.
const FONT = preload("res://assets/ui_font.ttc")
const ART = preload("res://scripts/art.gd")
const PLANT = preload("res://assets/art/prop-plant-big.png")
const SMALL_PLANT = preload("res://assets/art/prop-plant-small.png")
const ROCK = preload("res://assets/art/prop-stone.png")
const HEAD = preload("res://assets/art/prop-stone-head.png")
const CAVE = preload("res://assets/art/cave-middleground-no-fungus.png")
const WATER_TILES = preload("res://assets/art/water-tiles.png")
const ANTENNA = preload("res://assets/art/water-antenna.png")
const TRUCK = preload("res://assets/art/water-v-truck.png")
const SHIP = preload("res://assets/art/water-v-police.png")
const BOX = preload("res://assets/art/water-control-box-3.png")
var game: Node
var time: float = 0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	_draw_art_scenery()

func _draw_art_scenery() -> void:
	if not is_instance_valid(game.camera) or game.state=="menu": return
	if game.chapter>=3:
		_draw_water_region()
		return
	var left: float = game.camera.position.x-375
	var right: float = game.camera.position.x+375
	var chapter: int = game.chapter%3
	if chapter==1:
		var width: float = CAVE.get_width()*1.3
		var offset: float = fposmod((game.camera.position.x-320)*0.65,width)
		for i: int in range(-1,4):
			draw_texture_rect(CAVE,Rect2(game.camera.position.x-320+i*width-offset,72,width,CAVE.get_height()*1.3),false,Color("63817c"))
	for i: int in range(int(left/320)-1,int(right/320)+2):
		var x: float = i*320+145
		var tint: Color = [Color("88968d"),Color("699c92"),Color("ad8c79")][chapter]
		# Articulated industrial silhouettes with deliberately sparse warm focal points.
		if chapter==0:
			if posmod(i,3)==0:
				_ruin(Vector2(x,300),i)
			elif posmod(i,3)==1:
				draw_texture_rect(HEAD,Rect2(x-38,226,72,76),false,Color("84938a"))
			else:
				ART.stamp(self,Rect2(192,64,64,48),Rect2(x-38,208,84,90),tint)
			_cable(Vector2(x-160,167),Vector2(x+160,145),24)
		elif chapter==1:
			ART.tile_strip(self,Rect2(176,112,48,32),Vector2(x-165,110),335,25,tint.darkened(0.28))
			ART.stamp(self,Rect2(272,0,16,64),Rect2(x+76,114,18,185),tint)
			for j: int in range(4):
				var plant_x: float = x-140+j*71
				var scale_value: float = 0.9+posmod(i+j,3)*0.15
				draw_texture_rect(PLANT,Rect2(plant_x,300-PLANT.get_height()*scale_value,PLANT.get_width()*scale_value,PLANT.get_height()*scale_value),false,Color("98b89e"))
			if posmod(i,2)==0: _tank(Vector2(x+120,300))
		else:
			_factory(Vector2(x,300),i)
			ART.stamp(self,Rect2(336,64,32,80),Rect2(x-45,180,60,120),tint)
			_chain(Vector2(x+150,-10),215)
			_gear(Vector2(x+150,186),29,time*0.2+i,Color("65544c"))
			_cable(Vector2(x-160,120),Vector2(x+160,113),20)
		# Railings and thin support lattice stay behind the playable surface.
		ART.tile_strip(self,Rect2(0,0,64,16),Vector2(x-132,280),245,20,tint.darkened(0.38))
		for px: float in [x-128,x-7,x+110]:
			ART.stamp(self,Rect2(272,0,16,64),Rect2(px,253,4,47),tint)
	for floor_rect: Rect2 in game.platforms:
		if floor_rect.end.x<left or floor_rect.position.x>right: continue
		if floor_rect.size.y<30:
			for j: int in range(2): _vine(floor_rect.position+Vector2(20+j*47,12),19+j*11,j)
			continue
		for i: int in range(int(floor_rect.size.x/79)):
			var x: float = floor_rect.position.x+i*79+28
			if x<left or x>right: continue
			var p: Vector2 = Vector2(x,floor_rect.position.y)
			if chapter<2:
				var plant_tex: Texture2D = SMALL_PLANT if i%3==0 else ROCK
				var h: float = 18 if i%3==0 else 12
				var w: float = plant_tex.get_width()*h/plant_tex.get_height()
				draw_texture_rect(plant_tex,Rect2(p-Vector2(w*0.5,h),Vector2(w,h)),false,Color("9caf94"))
				_grass(p,i)
			else:
				ART.stamp(self,Rect2(32,176,32,16),Rect2(p-Vector2(12,12),Vector2(25,12)),Color("7f7b70"))
	# Pools are strictly below the collision surface, framing dangerous gaps.
	for i: int in range(int(left/12),int(right/12)+1):
		var x: float = i*12
		var solid: bool = false
		for floor_rect: Rect2 in game.platforms:
			if floor_rect.size.y>30 and x>=floor_rect.position.x and x<=floor_rect.end.x: solid = true
		if not solid and x>0 and x<game.level_width:
			var col: Color = Color("d98954") if chapter==2 else Color("4c9293")
			draw_rect(Rect2(x,332+sin(time*2+i)*2,12,28),Color(col,0.16))
			draw_line(Vector2(x,332+sin(time*2+i)*2),Vector2(x+9,332+sin(time*2+i)*2),Color(col,0.45),1)
			draw_rect(Rect2(x+5,355-fposmod(time*15+i*11,30),1,2),Color(col,0.7))

func _ruin(p: Vector2, seed_value: int) -> void:
	# Collapsed railway carriage, with braced windows, wheels and signage.
	draw_rect(Rect2(p+Vector2(-81,-76),Vector2(158,67)),Color("2a3e44"))
	draw_colored_polygon(PackedVector2Array([p+Vector2(-88,-75),p+Vector2(-73,-85),p+Vector2(61,-85),p+Vector2(81,-75)]),Color("435754"))
	draw_rect(Rect2(p+Vector2(-80,-74),Vector2(157,4)),Color("657367"))
	for i: int in range(5):
		var x: float = p.x-70+i*28
		draw_rect(Rect2(x,p.y-65,22,25),Color("1b2e37"))
		draw_rect(Rect2(x+2,p.y-63,18,20),Color("3c575a"))
		draw_rect(Rect2(x+3,p.y-62,6,18),Color("506d68"))
		draw_line(Vector2(x+2,p.y-47),Vector2(x+20,p.y-61),Color("809080"),1)
		if i==posmod(seed_value,5):
			draw_line(Vector2(x,p.y-62),Vector2(x+22,p.y-42),Color("263c42"),3)
	draw_rect(Rect2(p+Vector2(-80,-36),Vector2(156,4)),Color("987b5b"))
	draw_rect(Rect2(p+Vector2(-80,-32),Vector2(156,2)),Color("5f6556"))
	draw_string(FONT,p+Vector2(-27,-16),"NORTHLINE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("889786"))
	for x: int in [-56,51]:
		draw_circle(p+Vector2(x,-9),11,Color("172a33"))
		draw_circle(p+Vector2(x,-9),5,Color("4c5c5c"))
	for i: int in range(7):
		_grass(p+Vector2(-79+i*24,-76),i)
	_vine(p+Vector2(62,-80),60,seed_value)

func _draw_water_region() -> void:
	var left: float = game.camera.position.x-370
	var right: float = game.camera.position.x+370
	var stage: int = game.chapter-3
	for i: int in range(int(left/410)-1,int(right/410)+2):
		var x: float = i*410+175
		if stage==0:
			# Dock cranes, suspended cables and moored transports.
			ART.stamp(self,Rect2(272,0,16,64),Rect2(x-12,117,14,183),Color("75969b"))
			ART.tile_strip(self,Rect2(0,0,64,16),Vector2(x-37,109),182,14,Color("a0b4ab"))
			draw_line(Vector2(x,121),Vector2(x+133,121),Color("283f4b"),1)
			draw_line(Vector2(x+124,119),Vector2(x+124,218+sin(time+i)*5),Color("9cafac"),1)
			ART.stamp(self,Rect2(80,0,16,16),Rect2(x+107,218+sin(time+i)*5,33,30),Color("98a89c"))
			if posmod(i,3)==0: draw_texture_rect(TRUCK,Rect2(x-110,220,195,80),false,Color("a7b7b2"))
		elif stage==1:
			ART.tile_strip(self,Rect2(288,0,64,16),Vector2(x-200,92),425,18,Color("738e92"))
			for j: int in range(3):
				var px: float = x-160+j*165
				ART.stamp(self,Rect2(272,0,16,64),Rect2(px,105,10,195),Color("6c858a"))
				draw_line(Vector2(px,124),Vector2(px+160,208),Color("3e5864"),3)
			_cable(Vector2(x-210,153),Vector2(x+220,128),18)
			draw_texture_rect(ANTENNA,Rect2(x+100,187,26,114),false,Color("b6c7b7"))
			if posmod(i,3)==0: draw_texture_rect(SHIP,Rect2(x-90,256,119,44),false,Color("91aba9"))
		else:
			# A ring of enormous signal dishes surrounds the storm engine.
			draw_texture_rect(ANTENNA,Rect2(x-4,115,36,185),false,Color("8cb2b5"))
			var p: Vector2 = Vector2(x+15,145)
			draw_arc(p,39,-2.8,-.3,32,Color("577987"),6)
			draw_arc(p,31,-2.8,-.3,32,Color("263f50"),3)
			draw_line(p,p+Vector2(0,-28),Color("96c7c4"),2)
			draw_rect(Rect2(p+Vector2(-3,-32),Vector2(6,6)),Color("99d8cb"))
			_cable(Vector2(x-190,112),Vector2(x+230,100),32)
		draw_texture_rect(BOX,Rect2(x-60,266,70,34),false,Color("a4bfb6"))
	for rect: Rect2 in game.platforms:
		if rect.end.x<left or rect.position.x>right: continue
		if rect.size.y<30:
			for x: float in [rect.position.x+7,rect.end.x-10]:
				draw_line(Vector2(x,rect.position.y),Vector2(x,rect.position.y-13),Color("687f80"),1)
			draw_line(rect.position-Vector2(-6,13),Vector2(rect.end.x-8,rect.position.y-13),Color("788d87"),1)
		else:
			for i: int in range(int(rect.size.x/125)):
				var x: float = rect.position.x+i*125+25
				if x<left or x>right: continue
				draw_texture_rect(preload("res://assets/art/prop-stone.png"),Rect2(x,289,20,11),false,Color("6c9991"))
				if stage==0: _grass(Vector2(x+20,300),i)

func _tree(p: Vector2, scale_value: float, color: Color) -> void:
	draw_set_transform(p,0,Vector2.ONE*scale_value)
	draw_colored_polygon(PackedVector2Array([Vector2(-12,0),Vector2(-3,-75),Vector2(-11,-120),Vector2(-3,-134),Vector2(5,-85),Vector2(9,-39),Vector2(17,0)]),color)
	for i: int in range(8):
		var origin: Vector2 = Vector2(2,-50-i*10)
		var direction: float = -1 if i%2 else 1
		var end: Vector2 = origin+Vector2(direction*(31+i*2),-18-i%3*8)
		draw_line(origin,end,color,5-i%2)
		draw_line(end,end+Vector2(direction*13,-17),color,2)
		for j: int in range(7):
			var offset: Vector2 = Vector2(sin(i*17+j*3)*20,cos(i*9+j*2)*12)
			draw_rect(Rect2(end+offset,Vector2(10+j%3*3,5+j%2*3)),color.lightened(0.04+float(j%3)*0.025))
	draw_line(Vector2(2,-63),Vector2(8,-9),color.lightened(0.12),2)
	draw_set_transform(Vector2.ZERO)

func _cable(a: Vector2,b: Vector2,sag: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(21):
		var t: float = i/20.0
		points.append(a.lerp(b,t)+Vector2(0,sin(t*PI)*sag))
	draw_polyline(points,Color("1c333c"),1)
	for i: int in range(2,19,4):
		var p: Vector2 = points[i]
		draw_line(p,p+Vector2(0,9),Color("405550"),1)
		draw_rect(Rect2(p+Vector2(-2,8),Vector2(4,5)),Color("d9b578"))
		draw_circle(p+Vector2(0,11),10,Color(0.9,0.7,0.4,0.05))

func _vine(p: Vector2,length_value: float,seed_value: int) -> void:
	var last: Vector2 = p
	for i: int in range(int(length_value/6)):
		var pos: Vector2 = p+Vector2(roundf(sin(i*0.7+seed_value+time*0.25)*3),i*6)
		draw_line(last,pos,Color("355d50"),1)
		last = pos
		draw_rect(Rect2(pos+Vector2(-5 if i%2 else 1,1),Vector2(5,3)),Color("527b62") if i%3 else Color("709579"))

func _grass(p: Vector2,seed_value: int) -> void:
	for i: int in range(5):
		var tip: Vector2 = p+Vector2((i-2)*3+roundf(sin(time*2+seed_value)*2),-5-posmod(i*7+seed_value,10))
		draw_line(p+Vector2(i-2,0),tip,Color("597963"),1)
		if i%2: draw_rect(Rect2(tip-Vector2(1,2),Vector2(3,3)),Color("b8ac78"))

func _mushroom(p: Vector2,seed_value: int) -> void:
	var h: float = 5+posmod(seed_value,3)*3
	draw_rect(Rect2(p-Vector2(1,h),Vector2(2,h)),Color("477c74"))
	draw_rect(Rect2(p-Vector2(5,h+2),Vector2(10,3)),Color("61b7a5"))
	draw_rect(Rect2(p-Vector2(3,h+4),Vector2(6,2)),Color("a0d7ba"))
	draw_circle(p-Vector2(0,h),12,Color(0.3,0.95,0.7,0.04))

func _pipe(p: Vector2,size: Vector2,color: Color) -> void:
	draw_rect(Rect2(p,size),color.darkened(0.3))
	if size.x>size.y:
		draw_rect(Rect2(p+Vector2(0,3),Vector2(size.x,size.y*0.5)),color)
		draw_rect(Rect2(p+Vector2(0,4),Vector2(size.x,2)),color.lightened(0.13))
		for i: int in range(int(size.x/72)):
			draw_rect(Rect2(p+Vector2(i*72+20,-3),Vector2(7,size.y+6)),color.lightened(0.08))
	else:
		draw_rect(Rect2(p+Vector2(3,0),Vector2(size.x*0.5,size.y)),color)
		draw_rect(Rect2(p+Vector2(4,0),Vector2(2,size.y)),color.lightened(0.12))
		for i: int in range(int(size.y/50)):
			draw_rect(Rect2(p+Vector2(-3,i*50+20),Vector2(size.x+6,6)),color.lightened(0.08))

func _tank(p: Vector2) -> void:
	draw_rect(Rect2(p+Vector2(-36,-125),Vector2(72,125)),Color("20424a"))
	draw_rect(Rect2(p+Vector2(-29,-120),Vector2(56,114)),Color("2c5355"))
	draw_rect(Rect2(p+Vector2(-25,-117),Vector2(5,108)),Color("426e65"))
	for i: int in range(4):
		draw_rect(Rect2(p+Vector2(-39,-115+i*31),Vector2(78,5)),Color("3d615e"))
	draw_rect(Rect2(p+Vector2(-11,-88),Vector2(22,40)),Color("16373f"))
	for i: int in range(5): draw_rect(Rect2(p+Vector2(-7,-82+i*6),Vector2(14,3)),Color("5eab95"))
	draw_string(FONT,p+Vector2(-14,-22),"H₂O",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8daf97"))

func _factory(p: Vector2,seed_value: int) -> void:
	var height: float = 153+posmod(seed_value*31,65)
	draw_rect(Rect2(p+Vector2(-85,-height),Vector2(170,height)),Color("262d34"))
	draw_rect(Rect2(p+Vector2(-91,-height-6),Vector2(182,8)),Color("524b46"))
	for i: int in range(4):
		var x: float = p.x-69+i*39
		draw_rect(Rect2(x,p.y-height+16,27,height-36),Color("18232b"))
		for j: int in range(6):
			draw_rect(Rect2(x+3,p.y-height+20+j*21,21,14),Color("6b4938") if (i+j)%3 else Color("a96942"))
			draw_rect(Rect2(x+13,p.y-height+15,3,height-36),Color("33383a"))
	for i: int in range(2):
		var x: float = p.x-51+i*100
		_pipe(Vector2(x,p.y-height-87),Vector2(19,91),Color("49433e"))
		for j: int in range(5):
			var t: float = fposmod(time*9+j*13+seed_value*17,60)
			draw_rect(Rect2(x-2+t*0.25,p.y-height-90-t,20+t*0.3,10),Color(0.2,0.2,0.23,0.5*(1-t/65)))

func _chain(p: Vector2,length_value: int) -> void:
	for i: int in range(int(length_value/9)):
		draw_rect(Rect2(p+Vector2(-3,i*9),Vector2(6,8)),Color("625e53"),false,1)

func _gear(p: Vector2,radius: float,angle: float,color: Color) -> void:
	draw_circle(p,radius-4,color)
	for i: int in range(12):
		var a: float = angle+i*TAU/12
		var center: Vector2 = p+Vector2.from_angle(a)*(radius-1)
		draw_set_transform(center,a)
		draw_rect(Rect2(-5,-5,10,10),color)
	draw_set_transform(Vector2.ZERO)
	draw_circle(p,radius-10,Color("1c2930"))
	for i: int in range(5): draw_line(p,p+Vector2.from_angle(angle+i*TAU/5)*(radius-9),color,4)
	draw_circle(p,5,color.lightened(0.1))

