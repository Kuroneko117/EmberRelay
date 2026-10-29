extends Node2D

const ART = preload("res://scripts/art.gd")
const WATER_SKY = preload("res://assets/art/water-skyline-b.png")
const WATER_FAR = preload("res://assets/art/water-buildings-bg.png")
const WATER_NEAR = preload("res://assets/art/water-near-buildings-bg.png")

var game: Node
var clock: float = 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	_draw_new_landscape()

func _draw_new_landscape() -> void:
	if not is_instance_valid(game): return
	if game.chapter>=3 and game.state!="menu":
		_draw_water_sky()
		return
	var chapter: int = 0 if game.state=="menu" else game.chapter%3
	var scroll: float = game.camera.position.x-320 if game.state!="menu" else clock*4
	var ink: Color = [Color("182330"),Color("122833"),Color("291e2c")][chapter]
	draw_rect(Rect2(0,0,640,360),ink)
	# A restrained sky carries the dramatic light behind the sourced pixel skyline.
	var horizon: Color = [Color("ad7563"),Color("477b82"),Color("be694f")][chapter]
	for i: int in range(32):
		var y: float = i*10
		draw_rect(Rect2(0,y,640,10),ink.lerp(horizon,pow(float(i)/31,1.8)))
	var sun: Vector2 = Vector2(472-scroll*0.018,119)
	for i: int in range(5,0,-1): draw_circle(sun,37+i*6,Color(horizon,0.025))
	draw_circle(sun,37,Color("f4c99c") if chapter!=1 else Color("b3d2c7"))
	if chapter==1: draw_circle(sun+Vector2(15,-10),33,ink)
	for i: int in range(6):
		var x: float = fposmod(i*143-clock*2-scroll*0.07,830)-90
		draw_rect(Rect2(x,58+i%3*24,110,3),Color(horizon,0.18))
	var layers: Array[Texture2D] = [ART.FAR,ART.CITY,ART.NEAR]
	var palette: Array[Color] = [Color("a7aac1"),Color("84b7c7"),Color("d6a4ad")]
	for i: int in range(3):
		var tex: Texture2D = layers[i]
		var sc: float = 2.0
		var width: float = tex.get_width()*sc
		var offset: float = floorf(fposmod(scroll*[0.07,0.18,0.35][i],width))
		for j: int in range(-1,4):
			draw_texture_rect(tex,Rect2(j*width-offset,315-tex.get_height()*sc,width,tex.get_height()*sc),false,palette[chapter])
		if i<2: draw_rect(Rect2(0,194+i*45,640,130),Color(horizon,0.035))
	# A distant aerial tram and its cable break up the repeating city silhouette.
	var cable_y: float = 117 if chapter==0 else 90
	draw_line(Vector2(0,cable_y),Vector2(640,cable_y+38),Color("26303b"),1)
	var tram_start: float = 480 if game.state=="menu" else 330
	var tram: Vector2 = Vector2(fposmod(clock*7-scroll*0.12+tram_start,800)-80,cable_y+20)
	draw_line(tram-Vector2(0,8),tram+Vector2(0,15),Color("303d47"),2)
	draw_style_box(_tram_style(),Rect2(tram+Vector2(-15,13),Vector2(30,19)))
	for i: int in range(3): draw_rect(Rect2(tram+Vector2(-11+i*8,17),Vector2(5,6)),Color("bba27b"))
	if chapter==1:
		for i: int in range(82):
			var rain: Vector2 = Vector2(fposmod(i*73-clock*31-scroll*0.5,660)-10,fposmod(i*39+clock*185,360))
			draw_line(rain,rain+Vector2(-2,8),Color(0.63,0.79,0.79,0.18),1)
	else:
		for i: int in range(35):
			var p: Vector2 = Vector2(fposmod(i*97-clock*(4+i%4)-scroll*0.3,660)-10,360-fposmod(i*41+clock*(6+i%6),360))
			draw_rect(Rect2(p,Vector2(1,1+i%2)),Color("e9b67b")*Color(1,1,1,0.45))
	# Screen-edge shade leaves the active playfield brighter.
	for i: int in range(6):
		draw_rect(Rect2(0,i*5,640,5),Color(0.03,0.06,0.1,0.12*(1-i/6.0)))

func _tram_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("293744")
	style.border_color = Color("5d6972")
	style.set_border_width_all(1)
	return style

func _draw_water_sky() -> void:
	var scroll: float = game.camera.position.x-320
	var stage: int = game.chapter-3
	var tint: Color = [Color("a1c7c8"),Color("c5c9b3"),Color("8dabbc")][stage]
	draw_rect(Rect2(0,0,640,360),Color("142531"))
	for i: int in range(-1,4):
		draw_texture_rect(WATER_SKY,Rect2(i*256-floorf(fposmod(scroll*.025,256)),-80,256,480),false,tint)
	for layer: int in range(2):
		var tex: Texture2D = WATER_FAR if layer==0 else WATER_NEAR
		var sc: float = 2.0 if layer==0 else 1.0
		var width: float = tex.get_width()*sc
		var offset: float = floorf(fposmod(scroll*(0.12 if layer==0 else 0.32),width))
		for i: int in range(-1,4):
			draw_texture_rect(tex,Rect2(i*width-offset,312-tex.get_height()*sc,width,tex.get_height()*sc),false,tint.darkened(.22 if layer==0 else .05))
	if stage==0:
		for i: int in range(8):
			var y: float = 299+i*8
			draw_rect(Rect2(0,y,640,8),Color(0.24,.52,.55,.07+i*.015))
			for j: int in range(7):
				var x: float = fposmod(j*111+clock*(4+i)-scroll*.45,680)-20
				draw_line(Vector2(x,y),Vector2(x+12+i*3,y),Color(.59,.78,.73,.18),1)
	elif stage==1:
		for i: int in range(11):
			var x: float = fposmod(i*113+clock*26-scroll*.4,690)-25
			var y: float = 80+i*22
			draw_line(Vector2(x,y),Vector2(x+30,y),Color(.74,.81,.71,.13),1)
	else:
		for i: int in range(95):
			var p: Vector2 = Vector2(fposmod(i*73-clock*40-scroll*.4,680)-20,fposmod(i*39+clock*180,360))
			draw_line(p,p+Vector2(-4,11),Color(.57,.76,.82,.18),1)
		var flash: float = fposmod(clock,9)
		if flash>8.65 and flash<8.76: draw_rect(Rect2(0,0,640,360),Color(.6,.8,.87,.10))
	for i: int in range(5):
		var x: float = fposmod(i*151+clock*3-scroll*.2,850)-120
		draw_rect(Rect2(x,255+i*15,200,22),Color(.27,.47,.5,.04))

