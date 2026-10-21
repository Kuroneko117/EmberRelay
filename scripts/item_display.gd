extends Control
## Artist-drawn inventory sprite on a quiet equipment inspection pedestal.
var item: String = "blade"
var accent: Color = Color("ecb371")
var texture: Texture2D
var age: float = 0
var selected: bool = false

func _ready() -> void:
	var source: Texture2D = load("res://assets/ui/items/"+item+".png")
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = source.get_image().get_used_rect()
	texture = atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size*0.5
	if is_instance_valid(texture):
		var zoom: int = clampi(int(minf((size.x-20)/texture.get_width(),(size.y-10)/texture.get_height())),1,4)
		var extent: Vector2 = texture.get_size()*zoom
		var p: Vector2 = (center-extent*0.5).round()
		draw_texture_rect(texture,Rect2(p,extent),false)
		if selected: draw_line(Vector2(center.x-18,size.y-2),Vector2(center.x+18,size.y-2),accent,2)
