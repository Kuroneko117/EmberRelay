extends Control
## Native controls supply focus, mouse and keyboard activation over the illustrated title.
var game: Node
var stack: VBoxContainer
var footer: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_resource: Theme = Theme.new()
	theme_resource.default_font = preload("res://assets/ui_font.ttc")
	theme_resource.default_font_size = 11
	for key: String in ["normal","hover","pressed","focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.07,0.14,0.18,0.15) if key=="normal" else Color(0.16,0.25,0.28,0.88)
		style.border_color = Color("6b8c89") if key=="normal" else Color("efbc7d")
		style.border_width_bottom = 1
		style.border_width_left = 0 if key=="normal" else 3
		style.content_margin_left = 16
		style.content_margin_right = 13
		theme_resource.set_stylebox(key,"Button",style)
	theme_resource.set_color("font_color","Button",Color("e9e2c9"))
	theme_resource.set_color("font_hover_color","Button",Color("fff4d7"))
	theme = theme_resource
	stack = VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stack.position = Vector2(38,222)
	stack.custom_minimum_size = Vector2(206,0)
	stack.add_theme_constant_override("separation",7)
	add_child(stack)
	footer = HBoxContainer.new()
	footer.position = Vector2(472,335)
	footer.add_theme_constant_override("separation",8)
	add_child(footer)
	for info: Array in [["制作名单","credits"],["离开","quit"]]:
		var control: Button = Button.new()
		control.text = info[0]
		control.custom_minimum_size = Vector2(65,19)
		control.add_theme_font_size_override("font_size",8)
		control.pressed.connect(_pressed.bind(info[1]))
		footer.add_child(control)
	game.screen_changed.connect(_screen_changed)
	game.menu_changed.connect(_screen_changed)
	_refresh()

func _refresh() -> void:
	visible = game.state=="menu"
	footer.visible = not game.menu_help
	for child: Node in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
	if not visible: return
	stack.position = Vector2(235,291) if game.menu_help else Vector2(38,218)
	stack.add_theme_constant_override("separation",5)
	stack.custom_minimum_size.x = 170 if game.menu_help else 206
	var data: Array[Dictionary] = game.get_buttons()
	for i: int in range(data.size()):
		var item: Dictionary = data[i]
		if item.action=="quit" and not game.menu_help: continue
		var button: Button = Button.new()
		button.text = ("%02d    "% (stack.get_child_count()+1))+item.label if not game.menu_help else item.label
		button.custom_minimum_size = Vector2(0,31 if i==0 else 23)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_pressed.bind(item.action))
		if item.primary:
			var primary: StyleBoxFlat = StyleBoxFlat.new()
			primary.bg_color = Color(0.18,0.25,0.26,0.30)
			primary.border_color = Color("e9b277")
			primary.border_width_left = 3
			primary.border_width_bottom = 1
			primary.content_margin_left = 13
			button.add_theme_stylebox_override("normal",primary)
			button.add_theme_color_override("font_color",Color("f2d5a6"))
		stack.add_child(button)
	call_deferred("_focus_first")
	# Loop directional navigation across the short menu; Tab follows the same order.
	var buttons: Array[Node] = stack.get_children()
	for i: int in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[posmod(i-1,buttons.size())].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i+1)%buttons.size()].get_path()

func _pressed(action: String) -> void:
	game.activate_button(action)
	_refresh()

func _screen_changed() -> void:
	call_deferred("_refresh")

func _focus_first() -> void:
	if not is_inside_tree() or not visible or stack.get_child_count()==0: return
	var first: Control = stack.get_child(0)
	if first.is_inside_tree() and not first.is_queued_for_deletion(): first.grab_focus()

