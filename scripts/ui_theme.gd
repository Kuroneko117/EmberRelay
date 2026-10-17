extends RefCounted
const FONT = preload("res://assets/ui_font.ttc")
const INK = Color("101e26")
const PAPER = Color("eee1c7")
const GOLD = Color("ecb371")
const TEAL = Color("83c8bc")
const MUTED = Color("92aaa8")

static func material(which: String="panel") -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load("res://assets/ui/"+which+".png")
	for side: int in range(4):
		box.set_texture_margin(side,5 if which in ["panel","slot"] else 6 if side in [SIDE_LEFT,SIDE_RIGHT] else 12 if side==SIDE_TOP else 5)
		box.set_content_margin(side,12 if side in [SIDE_LEFT,SIDE_RIGHT] else 14 if side==SIDE_TOP else 10)
	if which.begins_with("button"):
		for side: int in range(4): box.set_content_margin(side,8 if side in [SIDE_LEFT,SIDE_RIGHT] else 5)
	elif which=="slot": box.set_content_margin_all(3)
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
	theme.set_stylebox("focus","Button",flat(Color(0,0,0,0),GOLD,1))
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
