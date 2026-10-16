extends RefCounted
## Licensed pixel atlas, with explicit rectangles to preserve the source pixel grid.
const ATLAS = preload("res://assets/art/industrial_steel.png")
const RAW = preload("res://assets/art/industrial.png")
const SKY = preload("res://assets/art/city_sky.png")
const FAR = preload("res://assets/art/city_far.png")
const CITY = preload("res://assets/art/city_city.png")
const NEAR = preload("res://assets/art/city_near.png")

static func stamp(n: CanvasItem, source: Rect2, dest: Rect2, tint: Color=Color.WHITE) -> void:
	n.draw_texture_rect_region(ATLAS,dest,source,tint)

static func tile_strip(n: CanvasItem, source: Rect2, where: Vector2, width: float, height: float, tint: Color=Color.WHITE) -> void:
	var x: float = 0
	while x<width:
		var piece: float = minf(source.size.x,width-x)
		stamp(n,Rect2(source.position,Vector2(piece,source.size.y)),Rect2(where+Vector2(x,0),Vector2(piece,height)),tint)
		x += piece

static func terrain(n: Node2D, platforms: Array[Rect2], camera_x: float, chapter: int) -> void:
	var tint: Color = [Color("b8c4b8"),Color("99c5bd"),Color("c9a89c")][chapter%3]
	for floor_rect: Rect2 in platforms:
		if absf(floor_rect.get_center().x-camera_x)>floor_rect.size.x*0.5+355: continue
		var p: Vector2 = floor_rect.position
		if floor_rect.size.y>30:
			n.draw_rect(floor_rect,Color("141e29"))
			for row: int in range(0,5):
				tile_strip(n,Rect2(288,0,64,16),p+Vector2(0,15+row*16),floor_rect.size.x,16,tint.darkened(0.26+row*0.08))
			tile_strip(n,Rect2(0,128,64,16),p,floor_rect.size.x,16,tint)
			n.draw_line(p,p+Vector2(floor_rect.size.x,0),Color("91a6a0"),1)
			for xx: int in range(8,int(floor_rect.size.x)-20,72):
				stamp(n,Rect2(0,96,16,32),Rect2(p+Vector2(xx,23),Vector2(16,32)),tint.darkened(0.1))
			for xx: float in [p.x+2,floor_rect.end.x-6]:
				n.draw_rect(Rect2(xx,p.y+3,4,10),Color("ddb474"))
		else:
			tile_strip(n,Rect2(0,0,64,16),p,floor_rect.size.x,16,tint.lightened(0.06))
			n.draw_rect(Rect2(p,Vector2(floor_rect.size.x,2)),Color("9aafa3"))
			for xx: float in [p.x+6,floor_rect.end.x-9]:
				stamp(n,Rect2(272,0,16,64),Rect2(xx,p.y+12,5,35),tint.darkened(0.15))

static func city_layers(n: CanvasItem, scroll: float, chapter: int, clock: float) -> void:
	var tint: Color = [Color("e5b6a2"),Color("a2d3c9"),Color("f4a482")][chapter%3]
	n.draw_texture_rect(SKY,Rect2(0,0,640,360),false,tint)
	var layers: Array[Texture2D] = [FAR,CITY,NEAR]
	for i: int in range(3):
		var tex: Texture2D = layers[i]
		var sc: float = 1.7 if i<2 else 1.55
		var width: float = tex.get_width()*sc
		var offset: float = fposmod(scroll*[0.09,0.22,0.40][i],width)
		for j: int in range(-1,4):
			var destination: Rect2 = Rect2(j*width-offset,310-tex.get_height()*sc,width,tex.get_height()*sc)
			n.draw_texture_rect(tex,destination,false,tint.darkened(0.18 if i==0 else 0.05))
	for i: int in range(30):
		var p: Vector2 = Vector2(fposmod(i*97-clock*(5+i%4)-scroll*0.2,660)-10, fposmod(i*41+sin(clock+i)*5,330))
		n.draw_rect(Rect2(p,Vector2(1,1)),Color("f4bc79")*Color(1,1,1,0.4))

