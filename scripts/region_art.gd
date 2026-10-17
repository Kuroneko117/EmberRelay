extends Control
## Illustration assembled from the same licensed pixel layers used by the levels.
const ART = preload("res://scripts/art.gd")
const UNITS = preload("res://scripts/enemy_visual.gd")
var region: int = 0
var show_boss: bool = true
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("122630") if region==1 else Color("302c2c"))
	var sky: Texture2D = ART.SKY if region==0 else preload("res://assets/art/water-skyline-a.png")
	draw_texture_rect(sky,Rect2(Vector2.ZERO,size),false,Color("b9a393") if region==0 else Color("86a8ac"))
	var textures: Array = [ART.FAR,ART.CITY,ART.NEAR] if region==0 else [preload("res://assets/art/water-buildings-bg.png"),preload("res://assets/art/water-near-buildings-bg.png")]
	for i: int in range(textures.size()):
		var tex: Texture2D = textures[i]
		var scale_factor: float = size.y/float(tex.get_height())*(0.8+i*0.15)
		var width: float = tex.get_width()*scale_factor
		for j: int in range(-1,4): draw_texture_rect(tex,Rect2(j*width-i*21,size.y-tex.get_height()*scale_factor,width,tex.get_height()*scale_factor),false,Color("bd9c80") if region==0 else Color("8ab5b0"))
	if region==0: draw_circle(Vector2(size.x*0.73,size.y*0.28),size.y*0.21,Color("dba76e"))
	if show_boss:
		var frames: SpriteFrames = UNITS.frames_for("boss" if region==0 else "tempest")
		var tex: Texture2D = frames.get_frame_texture("idle",0)
		var scale_factor: float = 1.15 if region==0 else 1.7
		draw_texture_rect(tex,Rect2(size.x-110,size.y-64*scale_factor,80*scale_factor,80*scale_factor),false)
	for i: int in range(10): draw_rect(Rect2(0,size.y-i*3,size.x,3),Color(0.035,0.08,0.11,0.8-i*0.07))
	draw_rect(Rect2(0,size.y-1,size.x,1),Color("5c7c7d"))
