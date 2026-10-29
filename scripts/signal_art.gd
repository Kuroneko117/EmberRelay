extends Control
## Native Aseprite cels, kept at integer magnification on the UI canvas.
var asset: String = "coil":
	set(value):
		asset = value
		if is_node_ready(): _load_art()
var magnification: int = 1
var frame_index: int = 0
var age: float = 0
var texture: Texture2D
var frame_size: Vector2 = Vector2(64,64)
const DURATIONS = [0.18,0.12,0.12,0.18]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	_load_art()

func _load_art() -> void:
	texture = load("res://assets/ui/signal/"+asset+".sheet.png")
	frame_size = Vector2(32,40) if asset=="signal-badge" else Vector2(64,64)
	frame_index = 0
	age = 0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	age += delta
	if age>=DURATIONS[frame_index]:
		age = fmod(age,DURATIONS[frame_index])
		frame_index = (frame_index+1)%4
		queue_redraw()

func _draw() -> void:
	if texture==null: return
	var extent: Vector2 = frame_size*magnification
	draw_texture_rect_region(texture,Rect2(((size-extent)*0.5).round(),extent),Rect2(Vector2(frame_index*frame_size.x,0),frame_size))
