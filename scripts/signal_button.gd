extends Button
## Native focus/click behavior with the original Figma button assets.
const ARROW_PAPER = preload("res://assets/ui/signal/arrow-paper.svg")
const ARROW_INK = preload("res://assets/ui/signal/arrow-ink.svg")
const ARROW_DISABLED = preload("res://assets/ui/signal/arrow-disabled.svg")

func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	preload("res://scripts/ui_theme.gd").style_action(self)
	for event: Signal in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up]: event.connect(queue_redraw)
	focus_entered.connect(_focus_style)
	focus_exited.connect(_focus_style)

func _focus_style() -> void:
	add_theme_stylebox_override("normal",preload("res://scripts/ui_theme.gd").action_skin("hover" if has_focus() else "default"))

func _draw() -> void:
	var hot: bool = not disabled and (has_focus() or is_hovered()) and not is_pressed()
	var arrow: Texture2D = ARROW_DISABLED if disabled else ARROW_INK if hot else ARROW_PAPER
	draw_texture_rect(arrow,Rect2(size.x-25,floorf(size.y/2)-5,12,10),false)
	var top: Color = Color("3d555e") if disabled else Color("f4c17c") if hot or is_pressed() else Color("637e80")
	draw_line(Vector2(1,0),Vector2(size.x-7,0),top,1)
	draw_rect(Rect2(1,3,2,maxf(1,size.y-6)),Color("3d555e") if disabled else Color("f4c17c"))
	if has_focus() and not disabled:
		var cream: Color = Color("fff1d0")
		draw_rect(Rect2(5,4,7,1),cream)
		draw_rect(Rect2(5,4,1,5),cream)
		draw_rect(Rect2(size.x-12,size.y-5,7,1),cream)
		draw_rect(Rect2(size.x-6,size.y-9,1,5),cream)
