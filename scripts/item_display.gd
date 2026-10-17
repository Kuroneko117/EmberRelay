extends Control
## Artist-drawn inventory sprite on a quiet equipment inspection pedestal.
var item: String = "blade"
var accent: Color = Color("ecb371")
var texture: Texture2D
var age: float = 0
var selected: bool = false

func _ready() -> void:
	texture = load("res://assets/ui/items/"+item+".png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size*0.5
	var radius: float = minf(size.x*0.35,31)
	draw_circle(center,32,Color(accent,0.035 if not selected else 0.08))
	draw_arc(center,radius,0,TAU,48,Color(accent,0.18),1)
	draw_line(Vector2(center.x-25,size.y-6),Vector2(center.x+25,size.y-6),Color(accent,0.35),1)
	for side: int in [-1,1]:
		var p: Vector2 = center+Vector2(side*(radius+7),0)
		draw_line(p,p+Vector2(-side*4,-4),Color(accent,0.6),1)
		draw_line(p,p+Vector2(-side*4,4),Color(accent,0.6),1)
	if is_instance_valid(texture):
		var zoom: int = 3 if size.y>=65 else 2
		var extent: Vector2 = Vector2(24,24)*zoom
		draw_texture_rect(texture,Rect2((center-extent*0.5+Vector2(0,roundf(sin(age*1.7)*1.5))).round(),extent),false)
