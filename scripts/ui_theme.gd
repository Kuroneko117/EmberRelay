extends RefCounted
const P = preload("res://scripts/visual_palette.gd")
const FONT = preload("res://assets/ui_font.ttc")
const DISPLAY = preload("res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf")
const INK = P.INK
const PAPER = P.PAPER
const GOLD = P.GOLD
const TEAL = P.SIGNAL
const MUTED = P.LIGHT
const STEEL = P.STEEL
const EDGE = P.EDGE
const ORANGE = P.ORANGE

static func action_skin(state: String="default") -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load("res://assets/ui/signal/button-"+state+".svg")
	for side: int in range(4):
		box.set_texture_margin(side,8)
		box.set_content_margin(side,13 if side==SIDE_LEFT else 32 if side==SIDE_RIGHT else 5)
	return box

static func style_action(button: Button) -> void:
	button.theme_type_variation = "SignalAction"
	for state: String in ["normal","hover","pressed","disabled"]:
		button.add_theme_stylebox_override(state,action_skin("default" if state=="normal" else state))
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",PAPER)
	button.add_theme_color_override("font_focus_color",INK)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_color_override("font_pressed_color",PAPER)
	button.add_theme_color_override("font_hover_pressed_color",PAPER)
	button.add_theme_color_override("font_disabled_color",EDGE)

static func module_frame(active: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/studio/signal-ui/module-frame-"+("focus" if active else "default")+".svg")
	for side: int in range(4):
		box.set_texture_margin(side,8)
		box.set_content_margin(side,9)
	return box

static func material(which: String="panel") -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.035,0.075,0.095,0.96)
	for side: int in range(4): box.set_content_margin(side,12 if side in [SIDE_LEFT,SIDE_RIGHT] else 12)
	if which.begins_with("button"):
		box.bg_color = Color("203a40") if which=="button-active" else Color(0.13,0.22,0.24,0.4)
		box.border_color = GOLD if which=="button-active" else Color("304b50")
		box.border_width_left = 2 if which=="button-active" else 0
		box.border_width_bottom = 0 if which=="button-active" else 1
		for side: int in range(4): box.set_content_margin(side,9 if side in [SIDE_LEFT,SIDE_RIGHT] else 5)
	elif which=="slot":
		box.bg_color = Color(0.025,0.06,0.075,0.68)
		box.set_content_margin_all(3)
	return box

static func flat(color: Color,border: Color=Color.TRANSPARENT,thickness: int=0,padding: int=0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(thickness)
	box.set_content_margin_all(padding)
	return box

static func make_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 11
	theme.set_color("font_color","Label",PAPER)
	theme.set_constant("separation","VBoxContainer",7)
	theme.set_constant("separation","HBoxContainer",10)
	theme.set_stylebox("panel","PanelContainer",material())
	theme.set_stylebox("normal","Button",material("button"))
	theme.set_stylebox("hover","Button",material("button-active"))
	theme.set_stylebox("pressed","Button",material("button-active"))
	theme.set_stylebox("disabled","Button",flat(Color("182a31"),Color("344b51"),1))
	theme.set_stylebox("focus","Button",flat(Color(0.9,0.7,0.4,0.06),GOLD,1))
	theme.set_color("font_color","Button",PAPER)
	theme.set_color("font_hover_color","Button",Color("fff2d4"))
	theme.set_color("font_pressed_color","Button",Color("fff2d4"))
	theme.set_color("font_disabled_color","Button",Color("607c7e"))
	theme.set_stylebox("background","ProgressBar",flat(Color("0b171d")))
	theme.set_stylebox("fill","ProgressBar",flat(GOLD))
	var slider_track: StyleBoxFlat = flat(Color("0d1c24"),Color("526b70"),1)
	slider_track.content_margin_top = 3
	slider_track.content_margin_bottom = 3
	theme.set_stylebox("slider","HSlider",slider_track)
	theme.set_stylebox("grabber_area","HSlider",flat(TEAL))
	theme.set_stylebox("grabber_area_highlight","HSlider",flat(GOLD))
	return theme
