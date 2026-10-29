extends ProgressBar
## A native value model with pixel segments, updated by value/resizing events.
var segments: int = 6:
	set(count):
		segments = maxi(1,count)
		queue_redraw()
var gap: int = 3
var fill_color: Color = Color("f4c17c")
var track_color: Color = Color("3d555e")

func _ready() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("background",StyleBoxEmpty.new())
	add_theme_stylebox_override("fill",StyleBoxEmpty.new())
	value_changed.connect(func(_value: float) -> void: queue_redraw())
	resized.connect(queue_redraw)

func _draw() -> void:
	var total: float = maxf(0,(value-min_value)/(max_value-min_value))*segments
	for index: int in range(segments):
		var x: float = floorf(float(index)*size.x/segments)
		var right: float = floorf(float(index+1)*size.x/segments)-gap
		var rect: Rect2 = Rect2(x,0,maxf(1,right-x),size.y)
		draw_rect(rect,track_color)
		var fraction: float = clampf(total-index,0,1)
		if fraction>0:
			rect.size.x = maxf(1,floorf(rect.size.x*fraction))
			draw_rect(rect,fill_color)
