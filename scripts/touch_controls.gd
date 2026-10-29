extends Control
## Native, multi-pointer action overlay. UI graphics are imported art, never hit regions.
const FONT = preload("res://assets/ui_font.ttc")
const ART = "res://assets/studio/mobile/"
const LABELS = {"attack":"连斩", "pulse":"脉冲", "jump":"跳跃", "dash":"冲刺", "parry":"弹反", "heal":"修复", "burst":"爆发", "interact":"交互", "pause_game":"暂停", "local_map":"地图"}
const ICON_NAMES = {"pause_game":"pause", "local_map":"map"}
var game: Node
var action_rects: Dictionary = {}
var finger_actions: Dictionary = {}
var owned_actions: Dictionary = {}
var stick_center: Vector2
var stick_radius: float = 42.0
var stick_finger: int = -1
var stick_offset: Vector2 = Vector2.ZERO
var _art_nodes: Dictionary = {}
var _stick_base: TextureRect
var _stick_knob: TextureRect
var _cached_rect: Rect2
var _cached_visual: Dictionary = {}
var _textures: Dictionary = {}
var _last_opacity: float = -1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game.screen_changed.connect(_screen_changed)
	game.controls.changed.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	_stick_base = _texture("stick-base.png")
	_stick_knob = _texture("stick-knob.png")
	for action: String in LABELS:
		var panel: TextureRect = _texture("control-primary-normal.png" if action=="attack" else "control-normal.png")
		var glyph: TextureRect = _texture("icon-"+str(ICON_NAMES.get(action,action))+".png",panel)
		var label: Label = Label.new()
		label.text = LABELS[action]
		label.add_theme_font_override("font",FONT)
		label.add_theme_font_size_override("font_size",11 if action=="attack" else 10)
		label.add_theme_color_override("font_color",Color("eee4d0"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		_art_nodes[action] = {"panel":panel,"icon":glyph,"label":label}
	relayout()
	_screen_changed()

func _texture(file: String,parent: Node=null) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = _load_art(file)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	(parent if parent!=null else self).add_child(rect)
	return rect

func _load_art(file: String) -> Texture2D:
	if _textures.has(file): return _textures[file]
	var result: Texture2D = load(ART+file) if ResourceLoader.exists(ART+file) else null
	_textures[file] = result
	return result

func safe_rect() -> Rect2:
	var bounds: Rect2 = get_viewport_rect()
	if not OS.has_feature("mobile"): return bounds
	var physical: Rect2i = DisplayServer.get_display_safe_area()
	if physical.size.x<=0 or physical.size.y<=0: return bounds
	return logical_safe_rect(Rect2(physical),get_viewport().get_screen_transform(),bounds)

static func logical_safe_rect(physical: Rect2,screen_transform: Transform2D,bounds: Rect2=Rect2(0,0,640,360)) -> Rect2:
	var inverse: Transform2D = screen_transform.affine_inverse()
	var first: Vector2 = inverse*physical.position
	var last: Vector2 = inverse*physical.end
	var candidate: Rect2 = Rect2(first,last-first).abs().intersection(bounds)
	return candidate if candidate.size.x>0 and candidate.size.y>0 else bounds

func relayout() -> void:
	if not is_instance_valid(_stick_base): return
	release_all()
	_cached_rect = safe_rect()
	var area: Rect2 = _cached_rect.grow(-6)
	var scale_factor: float = game.controls.touch_scale
	stick_radius = 42.0*scale_factor
	stick_center = Vector2(area.position.x+65*scale_factor,area.end.y-42*scale_factor)
	_stick_base.position = stick_center-Vector2(56,32)*scale_factor
	_stick_base.size = Vector2(112,64)*scale_factor
	_stick_knob.size = Vector2(40,40)*scale_factor
	var definitions: Dictionary = {
		"attack":[Vector2(-64,-70),56.0], "jump":[Vector2(-27,-137),46.0],
		"pulse":[Vector2(-126,-109),44.0], "dash":[Vector2(-131,-40),44.0],
		"parry":[Vector2(-193,-63),44.0], "heal":[Vector2(-193,-133),44.0],
		"burst":[Vector2(-256,-46),44.0]}
	for action: String in definitions:
		var side: float = definitions[action][1]*scale_factor
		var center: Vector2 = area.end+definitions[action][0]*scale_factor
		action_rects[action] = Rect2(center-Vector2.ONE*side*0.5,Vector2.ONE*side)
	var context_center: float = minf(area.get_center().x,action_rects.burst.position.x-8-23*scale_factor)
	action_rects.interact = Rect2(Vector2(context_center-23*scale_factor,area.end.y-68*scale_factor),Vector2(46,46)*scale_factor)
	action_rects.pause_game = Rect2(area.end.x-40,area.position.y+2,40,40)
	action_rects.local_map = Rect2(area.end.x-86,area.position.y+2,40,40)
	for action: String in action_rects:
		var region: Rect2 = action_rects[action]
		var entry: Dictionary = _art_nodes[action]
		entry.panel.position = region.position
		entry.panel.size = region.size
		var icon_side: float = minf(28,region.size.x*0.54)
		entry.icon.size = Vector2.ONE*icon_side
		entry.icon.position = Vector2((region.size.x-icon_side)*0.5,region.size.y*0.11)
		entry.label.position = Vector2(0,region.size.y*0.64)
		entry.label.size = Vector2(region.size.x,16)
	_update_visuals()

func _screen_changed() -> void:
	release_all()
	visible = game.controls.touch_active and game.state in ["playing","boss_intro"]
	var combat_visible: bool = game.state=="playing"
	_stick_base.visible = combat_visible
	_stick_knob.visible = combat_visible
	for action: String in _art_nodes:
		_art_nodes[action].panel.visible = combat_visible or action=="pause_game"
	_update_visuals()

func _process(_delta: float) -> void:
	if not game.controls.touch_active: return
	if safe_rect()!=_cached_rect: relayout()
	if visible: _update_visuals()

func _update_visuals() -> void:
	var opacity: float = game.controls.touch_opacity
	if opacity!=_last_opacity:
		_stick_base.self_modulate.a = opacity
		_stick_knob.self_modulate.a = minf(1,opacity+0.12)
		for action: String in _art_nodes: _art_nodes[action].panel.self_modulate.a = opacity
		_last_opacity = opacity
	_stick_knob.position = stick_center+stick_offset*0.5-_stick_knob.size*0.5
	for action: String in _art_nodes:
		var disabled: bool = not action_available(action)
		var pressed: bool = owned_actions.has(action)
		var mode: String = "disabled" if disabled else "pressed" if pressed else "normal"
		if _cached_visual.get(action,"")==mode: continue
		_cached_visual[action] = mode
		_art_nodes[action].panel.texture = _load_art(("control-primary-" if action=="attack" else "control-")+mode+".png")
		_art_nodes[action].icon.modulate = Color("132229") if pressed and not disabled else Color(1,1,1,0.38 if disabled else 1.0)
		_art_nodes[action].label.modulate = Color(1,1,1,0.45 if disabled else 1.0)

func action_available(action: String) -> bool:
	if game.state=="boss_intro": return action=="pause_game"
	if game.state!="playing": return false
	if not is_instance_valid(game.player): return false
	match action:
		"heal": return game.director.potions>0 and game.player.health<game.player.max_health
		"burst": return game.director.focus>=100
		"pulse": return game.player.energy>=(14.0 if game.flame.module==0 and game.flame.charged>0 else 28.0)
		"dash": return game.player.dash_cooldown<=0
		"parry": return game.player.parry_cooldown<=0
	return true

func handle_event(event: InputEvent) -> bool:
	if not game.controls.touch_active: return false
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			var captured: bool = finger_actions.has(event.index) or stick_finger==event.index
			_release_finger(event.index)
			return captured or (visible and game.state=="playing")
		if not visible: return false
		if game.state=="playing" and stick_finger<0 and event.position.distance_to(stick_center)<=stick_radius*1.35:
			stick_finger = event.index
			_move_stick(event.position)
			return true
		for action: String in action_rects:
			if action_rects[action].has_point(event.position) and action_available(action):
				finger_actions[event.index] = action
				if action in ["pause_game","local_map"]:
					game.mobile_action(action)
				else:
					_press_action(action)
					game.mobile_action(action)
				return true
		return game.state=="playing"
	if event is InputEventScreenDrag:
		if event.index==stick_finger:
			_move_stick(event.position)
			return true
		if finger_actions.has(event.index):
			var action: String = finger_actions[event.index]
			if not action_rects[action].grow(14).has_point(event.position): _release_finger(event.index)
			return true
	return false

func _move_stick(position_in_view: Vector2) -> void:
	stick_offset = (position_in_view-stick_center).limit_length(stick_radius)
	_set_axis("move_left",maxf(0,-stick_offset.x/stick_radius))
	_set_axis("move_right",maxf(0,stick_offset.x/stick_radius))
	_set_axis("down",maxf(0,stick_offset.y/stick_radius))

func _set_axis(action: String,strength: float) -> void:
	if strength>0.28: _press_action(action,1.0 if action=="down" else inverse_lerp(0.28,1.0,strength))
	else: _release_action(action)

func _press_action(action: String,strength: float=1.0) -> void:
	owned_actions[action] = strength
	Input.action_press(action,strength)

func _release_finger(index: int) -> void:
	if index==stick_finger:
		stick_finger = -1
		stick_offset = Vector2.ZERO
		for action: String in ["move_left","move_right","down"]: _release_action(action)
	if finger_actions.has(index):
		var action: String = finger_actions[index]
		finger_actions.erase(index)
		if not finger_actions.values().has(action): _release_action(action)

func _release_action(action: String) -> void:
	if not owned_actions.has(action): return
	owned_actions.erase(action)
	Input.action_release(action)
	# Touch owns only its contribution. A connected physical key/pad may still hold it.
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and Input.is_physical_key_pressed(event.physical_keycode): Input.action_press(action)
		elif event is InputEventJoypadButton:
			for device: int in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(device,event.button_index): Input.action_press(action)
		elif event is InputEventJoypadMotion:
			for device: int in Input.get_connected_joypads():
				var value: float = Input.get_joy_axis(device,event.axis)*signf(event.axis_value)
				if value>InputMap.action_get_deadzone(action): Input.action_press(action,value)

func release_all() -> void:
	finger_actions.clear()
	stick_finger = -1
	stick_offset = Vector2.ZERO
	for action: String in owned_actions.keys(): _release_action(action)
	if is_instance_valid(_stick_knob): _update_visuals()

func _exit_tree() -> void:
	release_all()
