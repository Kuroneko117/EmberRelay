extends Control
## The terminal's native Control screens and event-driven HUD.
const T = preload("res://scripts/ui_theme.gd")
const REGION_ART = preload("res://scripts/region_art.gd")
const PORTRAIT = preload("res://scripts/unit_portrait.gd")
const SECTOR_MAP = preload("res://scripts/sector_map.gd")
const WORLD_ROUTE = preload("res://scripts/world_route.gd")
const ITEM_DISPLAY = preload("res://scripts/item_display.gd")
const SIGNAL_ART = preload("res://scripts/signal_art.gd")
const SIGNAL_BUTTON = preload("res://scripts/signal_button.gd")
const SEGMENTED_METER = preload("res://scripts/segmented_meter.gd")
const MODULE_ART = ["coil","ratchet","thruster"]
const MODULE_ROLES = ["弹反反击","连斩破阵","空中机动"]
var preview_module: int = 0
var game: Node
var screen: Control
var default_button: Button
var actions: Dictionary = {}
var fields: Dictionary = {}
var queued: bool = false
var building: bool = false
var toast_tween: Tween
var toast_box: PanelContainer
var view_revision: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = T.make_theme()
	game.screen_changed.connect(_queue_refresh)
	game.menu_changed.connect(_queue_refresh)
	game.sector_changed.connect(_queue_refresh)
	game.campaign.selection_changed.connect(_queue_refresh)
	game.stats_changed.connect(_sync_stats)
	game.notice_shown.connect(_notice)
	game.radio_received.connect(_radio)
	game.messages_dismissed.connect(_dismiss_toast)
	game.controls.changed.connect(_controls_changed)
	get_viewport().size_changed.connect(_queue_refresh)
	_refresh()

func _mobile() -> bool:
	return is_instance_valid(game.controls) and game.controls.touch_active

func _queue_refresh() -> void:
	if queued: return
	queued = true
	call_deferred("_refresh")

func _refresh() -> void:
	queued = false
	building = true
	view_revision += 1
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	if is_instance_valid(toast_tween): toast_tween.kill()
	toast_box = null
	actions.clear()
	fields.clear()
	default_button = null
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	if _mobile() and is_instance_valid(game.touch_controls):
		var safe: Rect2 = game.touch_controls.safe_rect()
		screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		screen.position = safe.position
		screen.size = safe.size
	match game.state:
		"menu":
			if game.menu_help: _help()
			else: _title()
		"world_map": _atlas()
		"playing", "boss_intro": _hud()
		"shop": _shop()
		"settings": _settings()
		"paused", "dead": _pause_or_retry()
		"upgrade": _reward()
		"victory": _ending()
		"credits": _credits()
		"asset_credits": _asset_credits()
		"journal": _journal()
		"bestiary": _bestiary()
		"attunement": _attunement()
		"controls": _controls()
	building = false
	_sync_stats()
	call_deferred("_focus_default")
	if game.state=="playing" and game.notice_timer>0: _notice(game.notice)
	elif game.state=="playing" and game.director.radio_time>0: _radio(game.director.radio)

func _focus_default() -> void:
	if is_instance_valid(default_button) and default_button.is_inside_tree() and not default_button.disabled: default_button.grab_focus()

func _controls_changed() -> void:
	if game.state in ["controls","menu"]: _queue_refresh()
	else: _sync_stats()

func _label(parent: Node,text: String,font_size: int=11,color: Color=T.PAPER,wrap: bool=false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",maxi(11,font_size) if _mobile() else font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func _vbox(parent: Node,gap: int=6) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

func _hbox(parent: Node,gap: int=8) -> HBoxContainer:
	var node: HBoxContainer = HBoxContainer.new()
	node.add_theme_constant_override("separation",gap)
	parent.add_child(node)
	return node

func _spacer(parent: Node,vertical: bool=true) -> Control:
	var node: Control = Control.new()
	if vertical: node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _icon(parent: Node,which: String,side: int=22,color: Color=T.PAPER) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	var item_path: String = "res://assets/ui/items/"+which+".png"
	var raster: bool = ResourceLoader.exists(item_path)
	node.texture = load(item_path if raster else "res://assets/ui/"+which+".svg")
	if raster:
		var cropped: AtlasTexture = AtlasTexture.new()
		cropped.atlas = node.texture
		cropped.region = node.texture.get_image().get_used_rect()
		node.texture = cropped
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(side,side)
	node.self_modulate = Color.WHITE if raster else color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _item_art(parent: Node,which: String,accent: Color=T.GOLD) -> Control:
	var art: Control = ITEM_DISPLAY.new()
	art.item = which
	art.accent = accent
	art.custom_minimum_size = Vector2(0,70)
	parent.add_child(art)
	return art

func _button(parent: Node,text: String,action: String,primary: bool=false,height: int=30) -> Button:
	var node: Button = SIGNAL_BUTTON.new() if primary else Button.new()
	node.name = "Action_"+action
	node.text = text.trim_suffix("→").strip_edges() if primary else text
	node.custom_minimum_size = Vector2(0,maxi(34,height) if _mobile() else height)
	if _mobile(): node.add_theme_font_size_override("font_size",12)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(_pressed.bind(action))
	node.focus_entered.connect(_focus_sound)
	parent.add_child(node)
	actions[action] = node
	if primary and not is_instance_valid(default_button): default_button = node
	return node

func _pressed(action: String) -> void:
	if action=="route_preview": game.start_route_preview(); return
	if action.begins_with("attune_"):
		_select_module(int(action.trim_prefix("attune_")))
		return
	if action=="equip_preview": game.flame.equip(preview_module); return
	if action=="controls": game.state = "controls"; return
	if action=="controls_back": game.controls.capture_action = ""; game.state = "settings"; return
	if action=="reset_keys": game.controls.reset_bindings(); return
	if action.begins_with("bind_"):
		game.controls.capture_action = action.trim_prefix("bind_")
		game.controls.status = "请按下新按键 · Esc 取消 · 不会覆盖已有绑定"
		_queue_refresh()
		return
	if action.begins_with("map_") and fields.has("area_map"):
		match action:
			"map_all": fields.area_map.overview()
			"map_center": fields.area_map.center_on_player()
			"map_plus": fields.area_map.zoom_by(0.75)
			"map_minus": fields.area_map.zoom_by(1.33)
		return
	if action=="bestiary": game.state = "bestiary"
	elif action=="bestiary_back": game.state = "menu"
	elif action=="asset_credits": game.state = "asset_credits"
	elif action=="credits_return": game.state = "credits"
	elif action.begins_with("region"):
		game.campaign.action(action)
		_queue_refresh()
	else:
		game.activate_button(action)
		if action=="settings_back": game.director.save_settings()
		if game.state in ["shop","settings","world_map"]: _queue_refresh()

func _focus_sound() -> void:
	if not building: game.audio.play_sfx("click")

func _margin(parent: Control,inset: int=22) -> MarginContainer:
	var node: MarginContainer = MarginContainer.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","top","right","bottom"]: node.add_theme_constant_override("margin_"+side,inset)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _veil(alpha: float=0.91) -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025,0.06,0.08,alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)

func _panel(parent: Node) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	parent.add_child(node)
	return node

func _modal(width: int=540,height: int=292) -> VBoxContainer:
	_veil()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel: PanelContainer = _panel(center)
	panel.custom_minimum_size = Vector2(minf(width,screen.size.x-20) if _mobile() else width,minf(height,screen.size.y-16) if _mobile() else height)
	return _vbox(panel,8)

func _header(parent: Node,_tag: String,title: String) -> HBoxContainer:
	var row: HBoxContainer = _hbox(parent)
	var column: VBoxContainer = _vbox(row,2)
	_display(column,title,25)
	_spacer(row,false)
	return row

func _display(parent: Node,text: String,font_size: int=28,color: Color=T.PAPER) -> Label:
	var label: Label = _label(parent,text,font_size,color)
	label.add_theme_font_override("font",T.DISPLAY)
	return label

func _rule(parent: Node,vertical: bool=false) -> ColorRect:
	var rule: ColorRect = ColorRect.new()
	rule.color = T.STEEL
	rule.custom_minimum_size = Vector2(1,1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical: rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(rule)
	return rule

func _signal_art(parent: Node,asset: String,extent: Vector2,zoom: int=1) -> Control:
	var art: Control = SIGNAL_ART.new()
	art.asset = asset
	art.magnification = zoom
	art.custom_minimum_size = extent
	parent.add_child(art)
	return art

func _link(parent: Node,text: String,action: String,font_size: int=9) -> Button:
	var link: Button = _button(parent,text,action,false,16)
	link.add_theme_font_size_override("font_size",11 if _mobile() else font_size)
	if _mobile(): link.custom_minimum_size.x = 44
	for state: String in ["normal","pressed","disabled"]: link.add_theme_stylebox_override(state,T.flat(Color.TRANSPARENT))
	link.add_theme_stylebox_override("hover",T.flat(Color(0.47,0.78,0.71,0.09)))
	link.add_theme_color_override("font_color",T.MUTED)
	link.add_theme_color_override("font_hover_color",T.PAPER)
	return link

func _title() -> void:
	var margin: MarginContainer = _margin(screen,28)
	margin.add_theme_constant_override("margin_top",22)
	margin.add_theme_constant_override("margin_bottom",32)
	var root_box: HBoxContainer = _hbox(margin,0)
	var left: VBoxContainer = _vbox(root_box,0)
	left.custom_minimum_size.x = 220
	var stamp: HBoxContainer = _hbox(left,7)
	stamp.custom_minimum_size.y = 27
	_signal_art(stamp,"signal-badge",Vector2(28,27))
	var byline: VBoxContainer = _vbox(stamp,4)
	byline.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(byline,"赤木作品",10,T.TEAL)
	_rule(byline).custom_minimum_size.x = 42
	var gap: Control = Control.new(); gap.custom_minimum_size.y = 5; left.add_child(gap)
	var brand: HBoxContainer = _hbox(left,43)
	brand.custom_minimum_size.y = 129
	var nameplate: Label = _display(brand,"余烬\n信使",59)
	nameplate.add_theme_constant_override("line_spacing",0)
	var english: VBoxContainer = _vbox(brand,2)
	english.alignment = BoxContainer.ALIGNMENT_CENTER
	_rule(english).custom_minimum_size = Vector2(23,2)
	_label(english,"E M B E R",10,T.GOLD)
	_label(english,"R E L A Y",10,T.GOLD)
	var quote: VBoxContainer = _vbox(left,5)
	_label(quote,"长夜将尽，沿着余光继续前行。",10,T.PAPER)
	_label(quote,"一束火种。两条穿越废城的航线。",9,T.MUTED)
	_spacer(left)
	_button(left,"继续旅程" if game.director.saved_available else "展开航线","continue" if game.director.saved_available else "start",true,32)
	var secondary: HBoxContainer = _hbox(left,6)
	secondary.custom_minimum_size.y = 0 if _mobile() and not game.director.saved_available else 34
	secondary.alignment = BoxContainer.ALIGNMENT_BEGIN
	if game.director.saved_available:
		_label(secondary,"＋",12,T.TEAL).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var next: Button = _link(secondary,"展开新航线","start",10)
		next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rule(left)
	var links: HBoxContainer = _hbox(left,12)
	links.custom_minimum_size.y = 28
	for entry: Array in [["手册","help"],["设置","settings"],["档案","bestiary"],["主创与致谢","credits"],["离开","quit"]]:
		_link(links,entry[0],entry[1],9).size_flags_vertical = Control.SIZE_SHRINK_END
	_spacer(root_box,false)
	var right: VBoxContainer = _vbox(root_box,0)
	right.custom_minimum_size.x = 118
	_label(right,"▪  移动信号在线" if _mobile() else "▪  信号在线",8,T.TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spacer(right)

func _atlas() -> void:
	_veil(0.98)
	var root_box: VBoxContainer = _vbox(_margin(screen,20),8)
	var head: HBoxContainer = _header(root_box,"LIGHTHOUSE NETWORK / 全域航线","余烬航线")
	_label(head,"%02d / 02\n航线已送达"%game.campaign.completed.size(),10,T.TEAL)
	var chart: Control = WORLD_ROUTE.new()
	chart.game = game
	chart.custom_minimum_size = Vector2(0,206)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(chart)
	for region: int in range(2):
		var selected: bool = game.campaign.selected==region
		var select: Button = _button(chart,"%02d  %s"%[region+1,game.campaign.REGIONS[region]],"region"+str(region),selected,24)
		select.add_theme_font_size_override("font_size",10)
		select.anchor_top = 0 if region==0 else 0.51
		select.anchor_bottom = select.anchor_top
		select.offset_left = 10
		select.offset_right = 142
		select.offset_top = 5
		select.offset_bottom = 29
	for sector: int in range(6):
		var node: Button = _button(chart,"%02d  %s"%[sector+1,game.chapter_names[sector]],"route_"+str(sector),false,28)
		var p: Vector2 = WORLD_ROUTE.POINTS[sector]
		node.anchor_left = p.x
		node.anchor_right = p.x
		node.anchor_top = p.y
		node.anchor_bottom = p.y
		node.offset_left = -54
		node.offset_right = 54
		node.offset_top = -14
		node.offset_bottom = 14
		node.add_theme_font_size_override("font_size",10)
		node.disabled = not game.campaign.visited.has(sector) and not (sector%3==0 and sector/3<=game.campaign.unlocked)
		if is_instance_valid(game.player) and game.chapter==sector: node.add_theme_color_override("font_color",T.GOLD)
	_label(root_box,"终点守卫 / "+game.campaign.BOSSES[game.campaign.selected]+"    ·    "+("航线已接通" if game.campaign.selected<=game.campaign.unlocked else "击败熔炉看守后接通"),9,T.MUTED)
	var footer: HBoxContainer = _hbox(root_box)
	_button(footer,"返回","atlas_back",false,28)
	if is_instance_valid(game.player): _button(footer,"区域图","local_map",false,28)
	_label(footer,"轻触航线与节点\n已探索节点可回访" if _mobile() else "1 / 2 选择航线\n已探索节点可回访",8,T.MUTED)
	_spacer(footer,false)
	var depart: Button = _button(footer,"前往「%s」  →"%game.campaign.REGIONS[game.campaign.selected],"depart",true,31)
	default_button = depart
	depart.disabled = game.campaign.selected>game.campaign.unlocked
	if depart.disabled: default_button = actions["region"+str(game.campaign.selected)]

func _bar(parent: Node,color: Color,height: int=5) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0,height)
	bar.add_theme_stylebox_override("fill",T.flat(color))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _hud() -> void:
	if _mobile():
		_mobile_hud()
		return
	if not is_instance_valid(game.player): return
	# The edge bands leave the playable middle clear, including the floor at y=300.
	for index: int in range(3):
		for lower: bool in [false,true]:
			var shade: ColorRect = ColorRect.new()
			shade.color = Color(T.INK,[0.18,0.45,0.65][index] if lower else [0.55,0.35,0.15][index])
			shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if lower else Control.PRESET_TOP_WIDE)
			shade.offset_top = -48+index*16 if lower else index*16
			shade.offset_bottom = shade.offset_top+16
			screen.add_child(shade)
	var top: MarginContainer = _margin(screen,10)
	top.anchor_bottom = 0
	top.offset_bottom = 65
	top.add_theme_constant_override("margin_top",8)
	top.add_theme_constant_override("margin_bottom",0)
	var row: HBoxContainer = _hbox(top,11)
	_signal_art(row,"signal-badge",Vector2(28,40)).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var info: VBoxContainer = _vbox(row,5)
	info.custom_minimum_size.x = 117
	var hp_row: HBoxContainer = _hbox(info,0)
	_label(hp_row,"信使 07",9,T.MUTED)
	_spacer(hp_row,false)
	fields.hp_text = _label(hp_row,"",9,T.GOLD)
	fields.hp = SEGMENTED_METER.new()
	fields.hp.custom_minimum_size = Vector2(117,5)
	info.add_child(fields.hp)
	fields.energy = _bar(info,T.TEAL,3)
	var resources: HBoxContainer = _hbox(info,5)
	_icon(resources,"ember",12,T.GOLD)
	fields.embers = _label(resources,"00",9,T.PAPER)
	_icon(resources,"memory",12,T.TEAL)
	fields.memories = _label(resources,"0 / 18",9,T.MUTED)
	fields.clock = _label(info,"",8,T.MUTED)
	fields.clock.visible = false
	_spacer(row,false)
	var goal: VBoxContainer = _vbox(row,3)
	goal.custom_minimum_size.x = 153
	var heading: HBoxContainer = _hbox(goal,6)
	var line: ColorRect = _rule(heading,true)
	line.color = T.TEAL
	line.custom_minimum_size = Vector2(2,12)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(heading,"%02d / %s"%[game.chapter+1,game.chapter_names[game.chapter]],11,T.PAPER)
	fields.goal = _label(goal,"",9,T.TEAL,true)
	fields.goal.custom_minimum_size.x = 153
	fields.goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom: MarginContainer = _margin(screen,18)
	bottom.anchor_top = 1
	bottom.offset_top = -45
	bottom.add_theme_constant_override("margin_top",0)
	bottom.add_theme_constant_override("margin_bottom",8)
	var lower: HBoxContainer = _hbox(bottom,14)
	for entry: Array in [["parry","parry"],["heal","repair"],["burst","burst"]]:
		var box: VBoxContainer = _vbox(lower,3)
		_icon(box,entry[1],16)
		var key: Label = _label(box,"",8,T.MUTED)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if entry[0]=="heal": fields.repairs = key
		elif entry[0]=="burst": fields.burst = key
		else: fields.parry = key
	_rule(lower,true).custom_minimum_size.y = 30
	var gauge: VBoxContainer = _vbox(lower,3)
	gauge.custom_minimum_size.x = 100
	fields.flame_status = _label(gauge,"",8,T.MUTED)
	fields.focus = SEGMENTED_METER.new()
	fields.focus.segments = 10
	fields.focus.gap = 2
	fields.focus.custom_minimum_size = Vector2(100,3)
	gauge.add_child(fields.focus)
	fields.equipped = _label(gauge,"",8,T.TEAL)
	_spacer(lower,false)
	fields.controls_hint = _label(lower,"",8,T.MUTED)
	fields.controls_hint.custom_minimum_size.x = 143
	var lesson: Label = _label(screen,"",8,T.MUTED,true)
	lesson.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lesson.offset_left = 190
	lesson.offset_right = -190
	lesson.offset_top = 16
	lesson.offset_bottom = 44
	lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson.add_theme_stylebox_override("normal",T.flat(Color(0.047,0.09,0.12,0.88)))
	fields.lesson = lesson
	var boss_holder: CenterContainer = CenterContainer.new()
	boss_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_holder.offset_top = 69
	boss_holder.offset_bottom = 99
	screen.add_child(boss_holder)
	fields.boss_holder = boss_holder
	var boss_box: VBoxContainer = _vbox(boss_holder,4)
	boss_box.custom_minimum_size.x = 280
	fields.boss_name = _label(boss_box,"",10,T.GOLD)
	fields.boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields.boss_hp = _bar(boss_box,T.GOLD,5)
	fields.combo = _label(screen,"",14,T.GOLD)
	fields.combo.position = Vector2(18,76)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 80
	center.offset_bottom = 132
	screen.add_child(center)
	toast_box = _panel(center)
	toast_box.custom_minimum_size.x = 316
	toast_box.visible = false
	var messages: VBoxContainer = _vbox(toast_box,1)
	fields.toast_title = _label(messages,"灯塔通讯 · 攻击收起",8,T.TEAL)
	fields.toast = _label(messages,"",10,T.PAPER,true)
	fields.toast.custom_minimum_size.x = 290
	fields.toast.custom_minimum_size.y = 25
	_set_passive(screen)
	if game.state=="boss_intro":
		var intro: PanelContainer = _panel(screen)
		intro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		intro.offset_top = -86
		var text: VBoxContainer = _vbox(intro,2)
		_label(text,"终点守卫",9,T.TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_display(text,game.campaign.BOSSES[game.chapter/3],28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(text,"ENTER 跳过登场",8,T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_passive(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _set_passive(child)

func _sync_stats() -> void:
	if building or fields.is_empty() or not is_inside_tree(): return
	if fields.has("mobile_hud"):
		_sync_mobile_stats()
		return
	if fields.has("module_hint"):
		fields.module_hint.text = "十字键预览 · → 确认\nA 装配 / B 返回" if game.controls.pad_active else "↑↓ 预览 · → 确认\n1 / 2 / 3 快捷装配"
	if fields.has("hp") and is_instance_valid(game.player):
		var p: Node = game.player
		fields.hp.max_value = p.max_health
		fields.hp.segments = p.max_health
		fields.hp.value = p.health
		fields.hp_text.text = "%d / %d"%[p.health,p.max_health]
		fields.energy.value = p.energy
		fields.focus.value = game.director.focus
		fields.embers.text = "%02d"%game.embers
		fields.memories.text = "%d / 18"%game.relics
		fields.clock.text = game.format_time(game.elapsed)
		fields.repairs.text = "%s ×%d"%[game.controls.prompt("heal"),game.director.potions]
		fields.parry.text = game.controls.prompt("parry")
		fields.burst.text = game.controls.prompt("burst")+(" 就绪" if game.director.focus>=100 else "")
		fields.flame_status.text = "共鸣  %d / 100"%int(game.director.focus)+(" · 返流" if game.flame.charged>0 else "")
		fields.equipped.text = game.flame.NAMES[game.flame.module]+" · 已装配" if game.flame.module>=0 else "支路中继 · 待装配"
		var nearby: bool = p.position.distance_to(game.flame.position_for())<50
		fields.controls_hint.text = ("%s  中继工坊"%game.controls.prompt("interact") if nearby else "%s  场景交互"%game.controls.prompt("interact"))+"\n%s  区域图 / %s  航线"%[game.controls.prompt("local_map"),game.controls.prompt("journal")]
		fields.lesson.text = game.flame.lesson_text
		fields.lesson.visible = not game.flame.lesson_text.is_empty()
		var target: Dictionary = game.guide.current()
		var objective: String = ("水力桥已通电 · 继续向东" if game.presentation.circuit_on else "穿过东侧检修口") if game.chapter==1 else _objective()
		fields.goal.text = objective+"\n"+game.guide.direction(target).replace("E ",game.controls.prompt("interact")+" ").replace("C ",game.controls.prompt("local_map")+" ")
		if (game.boss_awake and not game.boss_defeated) or game.director.active_arena>=0: _dismiss_toast()
		fields.combo.text = "%02d 连击"%game.director.combo if game.director.combo>=3 else ""
		fields.boss_holder.visible = game.boss_awake and not game.boss_defeated and is_instance_valid(game.boss)
		if fields.boss_holder.visible:
			fields.boss_name.text = game.campaign.BOSSES[game.chapter/3]+"  /  "+("核心过载" if game.boss.phase>=2 else "守护协议")
			fields.boss_hp.max_value = game.boss.max_health
			fields.boss_hp.value = game.boss.health
	if fields.has("shop_currency") and is_instance_valid(game.player):
		fields.shop_currency.text = "%d  余烬"%game.embers
		for index: int in range(3):
			var rank: int = game.damage_bonus if index==1 else game.pulse_bonus if index==2 else 0
			var price: int = 12 if index==0 else 30+15*rank if index==1 else 28+14*rank
			var full: bool = (index>0 and rank>=2) or (index==0 and game.player.health==game.player.max_health and game.director.potions>=2)
			var control: Button = actions[["buy_heal","buy_blade","buy_pulse"][index]]
			control.text = "补给充足" if index==0 and full else "已达上限" if full else "购买 · %d 余烬"%price
			control.disabled = full or game.embers<price
			fields["rank"+str(index)].text = "生命 %d/%d  修复 %d/2"%[game.player.health,game.player.max_health,game.director.potions] if index==0 else "当前等级  %d / 2"%rank

func _objective() -> String:
	var target: Dictionary = game.guide.current()
	if target.is_empty(): return "沿着余光前行"
	var prefix: String = "信标 %d/2 · "%game.guide.relay_count() if game.chapter==4 and target.kind=="device" else ""
	return prefix+target.title

func _dismiss_toast() -> void:
	if is_instance_valid(toast_tween): toast_tween.kill()
	if is_instance_valid(toast_box): toast_box.visible = false

func _notice(message: String) -> void:
	message = game.controls.adapt_text(message)
	if not is_instance_valid(toast_box) or game.state!="playing": return
	# Held attacks and active battles always keep the arena free of message panels.
	if Input.is_action_pressed("attack") or Input.is_action_pressed("pulse"):
		game.dismiss_messages()
		return
	if (game.boss_awake and not game.boss_defeated) or game.director.active_arena>=0:
		_dismiss_toast()
		return
	if is_instance_valid(toast_tween): toast_tween.kill()
	fields.toast_title.text = "北线投递处"
	fields.toast.text = message
	toast_box.visible = true
	toast_box.modulate.a = 1
	toast_tween = create_tween()
	toast_tween.tween_interval(maxf(0.4,(game.notice_timer if game.notice_timer>0 else game.director.radio_time)-0.3))
	toast_tween.tween_property(toast_box,"modulate:a",0.0,0.3)
	toast_tween.tween_callback(func() -> void: if is_instance_valid(toast_box): toast_box.visible = false)

func _radio(message: String) -> void:
	if game.notice_timer>0 or game.boss_awake or game.director.active_arena>=0: return
	_notice(message)
	if is_instance_valid(toast_box): fields.toast_title.text = "投递处通讯"

func _shop() -> void:
	var box: VBoxContainer = _modal(582,300)
	var head: HBoxContainer = _header(box,"RELAY 07 / MAINTENANCE","中继补给")
	_icon(head,"ember",21,T.GOLD)
	fields.shop_currency = _label(head,"",17,T.GOLD)
	var cards: HBoxContainer = _hbox(box,9)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index: int in range(3):
		var card: PanelContainer = _panel(cards)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",T.flat(Color("10222b"),Color.TRANSPARENT,0,8))
		var column: VBoxContainer = _vbox(card,5)
		_label(column,["01 / 维护补给","02 / 近战强化","03 / 远程强化"][index],8,T.MUTED)
		_item_art(column,["repair","blade","pulse"][index],T.GOLD if index<2 else T.TEAL)
		_label(column,["应急修复","刀锋组件","脉冲线圈"][index],16)
		_label(column,["完全治疗\n补充 1 瓶修复剂","每级近战伤害 +15%\n总强化不超过 +30%","每级射击伤害 +12%\n总强化不超过 +24%"][index],10,T.MUTED)
		_spacer(column)
		fields["rank"+str(index)] = _label(column,"",9,T.TEAL)
		_button(column,"",["buy_heal","buy_blade","buy_pulse"][index],false,28).add_theme_font_size_override("font_size",10)
	var foot: HBoxContainer = _hbox(box)
	_label(foot,"强化共享上限，保留余烬应对下一段路。",9,T.MUTED)
	_spacer(foot,false)
	default_button = _button(foot,"继续前进   →","close",true,28)

func _settings() -> void:
	if _mobile():
		_mobile_settings()
		return
	var box: VBoxContainer = _modal(480,286)
	_header(box,"COURIER TERMINAL / PREFERENCES","旅途设置")
	var audio_row: HBoxContainer = _hbox(box)
	_icon(audio_row,"pulse",22,T.TEAL)
	_label(audio_row,"主音量",12)
	var volume_value: Label = _label(audio_row,"%d%%"%roundi(game.director.volume*100),11,T.GOLD)
	var slider: HSlider = HSlider.new()
	slider.name = "VolumeSlider"
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = game.director.volume
	slider.custom_minimum_size = Vector2(180,24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		game.director.volume = value
		game.director.apply_volume()
		volume_value.text = "%d%%"%roundi(value*100))
	slider.drag_ended.connect(func(_changed: bool) -> void: game.director.save_settings())
	var shake: CheckButton = CheckButton.new()
	shake.text = "命中与爆发时的屏幕震动"
	shake.button_pressed = game.director.shake_enabled
	box.add_child(shake)
	shake.toggled.connect(func(enabled: bool) -> void:
		game.director.shake_enabled = enabled
		game.director.save_settings())
	var difficulty_row: HBoxContainer = _hbox(box)
	_label(difficulty_row,"旅途难度",12)
	var difficulty: OptionButton = OptionButton.new()
	difficulty.name = "DifficultySelector"
	for entry: String in ["漫游 · 更多生命与容错","标准 · 观察预警与反击","挑战 · 承受更高伤害"]: difficulty.add_item(entry)
	difficulty.select(game.director.difficulty)
	difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_row.add_child(difficulty)
	difficulty.item_selected.connect(func(index: int) -> void:
		game.director.difficulty = index
		game.director.save_settings())
	_label(box,"难度不改变成长上限。F11 切换全屏，M 静音。",10,T.MUTED)
	_button(box,"键位设置 / 手柄操作","controls",false,26)
	_spacer(box)
	default_button = _button(box,"保存并返回","settings_back",true,31)

func _controls() -> void:
	if _mobile():
		_mobile_controls()
		return
	var box: VBoxContainer = _modal(584,326)
	box.add_theme_constant_override("separation",4)
	_header(box,"INPUT / COURIER CONTROLS","操作与按键")
	_label(box,"手柄：A 跳跃 · X 近战 · Y 射击 · B 冲刺 · LB 弹反\nRB 交互 · LT 修复 · RT 爆发 · START 暂停 · BACK 航线 · RS 区域图",9,T.TEAL)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",2)
	box.add_child(grid)
	for i: int in range(game.controls.ACTIONS.size()):
		var action: String = game.controls.ACTIONS[i]
		_label(grid,game.controls.LABELS[i],10,T.MUTED).custom_minimum_size.x = 47
		var key: String = "等待按键…" if game.controls.capture_action==action else _keyboard_binding(action)
		var control: Button = _button(grid,key,"bind_"+action,false,21)
		control.custom_minimum_size.x = 202
		control.add_theme_font_size_override("font_size",10)
	_label(box,game.controls.status,9,T.GOLD)
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "显示情境教学提示"
	toggle.button_pressed = game.controls.lessons_enabled
	toggle.add_theme_font_size_override("font_size",10)
	box.add_child(toggle)
	toggle.toggled.connect(func(value: bool) -> void: game.controls.lessons_enabled = value; game.controls.save_config())
	var footer: HBoxContainer = _hbox(box)
	_button(footer,"恢复默认","reset_keys",false,27)
	_spacer(footer,false)
	default_button = _button(footer,"返回设置","controls_back",true,27)

func _keyboard_binding(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode)
	return "—"

func _attunement() -> void:
	preview_module = maxi(0,game.flame.module)
	_veil(0.88)
	var pad: MarginContainer = _margin(screen,28)
	pad.add_theme_constant_override("margin_top",18); pad.add_theme_constant_override("margin_bottom",8)
	var box: VBoxContainer = _vbox(pad,6)
	var header: HBoxContainer = _hbox(box)
	var words: VBoxContainer = _vbox(header,3)
	_display(words,"中继检修",24)
	_label(words,"返流、破甲、机动。只装一件。",10,T.MUTED)
	_spacer(header,false)
	var on: bool = game.flame.lit.has(game.chapter)
	_label(header,"已接通 · 免费更换" if on else "未接通 · 60 共鸣",10,T.GOLD)
	var gap: Control = Control.new(); gap.custom_minimum_size.y = 3; box.add_child(gap)
	var content: HBoxContainer = _hbox(box,38); content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = _vbox(content,8); left.custom_minimum_size.x = 248
	var plate: PanelContainer = _panel(left); plate.custom_minimum_size = Vector2(248,172)
	plate.add_theme_stylebox_override("panel",T.flat(Color("233942"),T.EDGE,1,0))
	var art_center: CenterContainer = CenterContainer.new(); plate.add_child(art_center)
	fields.module_art = TextureRect.new()
	fields.module_art.texture = load("res://assets/studio/coil.png")
	fields.module_art.custom_minimum_size = Vector2(128,128)
	fields.module_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fields.module_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_center.add_child(fields.module_art)
	var slots: HBoxContainer = _hbox(left,10)
	for index: int in range(3):
		var slot: VBoxContainer = _vbox(slots,2)
		var button: Button = _button(slot,"","attune_"+str(index),false,32)
		button.custom_minimum_size.x = 62
		var icon: TextureRect = TextureRect.new(); icon.texture = load("res://assets/studio/"+MODULE_ART[index]+".png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 15; icon.offset_right = -15; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(slot,["返流","破甲","机动"][index],10,T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_entered.connect(_select_module.bind(index))
		button.mouse_entered.connect(_select_module.bind(index))
		fields["module_role_"+str(index)] = _label(left,"",10); fields["module_role_"+str(index)].visible = false
	fields.module_hint = _label(left,"",10); fields.module_hint.visible = false
	var detail: VBoxContainer = _vbox(content,8); detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.module_role = _label(detail,"",11,T.TEAL)
	fields.module_name = _display(detail,"",22)
	fields.module_quote = _label(detail,"",11,T.PAPER,true)
	fields.module_description = _label(detail,"",11,T.MUTED,true)
	_spacer(detail)
	_button(detail,"","equip_preview",true,32)
	_label(detail,"接通后可免费更换，不叠加效果。",10,T.MUTED)
	_link(box,"返回旅途 · 取消不扣除共鸣" if _mobile() else "Esc 返回 · 取消不扣除共鸣","close",10)
	default_button = actions.equip_preview
	for index: int in range(3):
		actions["attune_"+str(index)].focus_neighbor_right = actions.equip_preview.get_path()
		actions["attune_"+str(index)].focus_neighbor_top = actions["attune_"+str((index+2)%3)].get_path()
		actions["attune_"+str(index)].focus_neighbor_bottom = actions["attune_"+str((index+1)%3)].get_path()
	_select_module(preview_module)

func _select_module(index: int) -> void:
	if not fields.has("module_name"): return
	preview_module = clampi(index,0,2)
	fields.module_role.text = MODULE_ROLES[index]
	fields.module_name.text = game.flame.NAMES[index]
	fields.module_art.texture = load("res://assets/studio/"+MODULE_ART[index]+".png")
	fields.module_quote.text = ["弹反后，下一发脉冲变强。","第三段命中，打断重装守卫。","空中射击时短暂悬停。"][index]
	fields.module_description.text = ["完美弹反 → 脉冲反击\n5 伤害 / 14 能量 / 8 秒内有效","第三击 → 恢复 10 共鸣\n每次挥击仅触发一次。","首次空中射击 → 悬停 0.16 秒\n冲刺冷却缩短 0.3 秒，落地重装。"][index]
	actions.equip_preview.text = "保持装配 · 返回" if game.flame.module==index else "装入"+game.flame.NAMES[index]
	actions.equip_preview.disabled = not game.flame.lit.has(game.chapter) and game.director.focus<60
	actions.equip_preview.focus_neighbor_left = actions["attune_"+str(index)].get_path()
	for item: int in range(3):
		var button: Button = actions["attune_"+str(item)]
		var slot_style: StyleBoxFlat = T.flat(Color("233942") if item==index else Color.TRANSPARENT)
		slot_style.border_color = T.ORANGE; slot_style.border_width_left = 2 if item==index else 0
		button.add_theme_stylebox_override("normal",slot_style)
		button.add_theme_color_override("font_color",T.INK)

func _pause_or_retry() -> void:
	var box: VBoxContainer = _modal(510,276)
	var dead: bool = game.state=="dead"
	_header(box,"SIGNAL LOST / 重启中继" if dead else "RELAY HOLD / 信号保持","火种尚未熄灭" if dead else "让火种歇一会儿")
	var row: HBoxContainer = _hbox(box,18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var illustration: Control = REGION_ART.new()
	illustration.region = game.chapter/3
	illustration.show_boss = false
	illustration.custom_minimum_size = Vector2(220,115)
	row.add_child(illustration)
	var menu: VBoxContainer = _vbox(row,6)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(menu,game.chapter_names[game.chapter],14,T.GOLD)
	_label(menu,"旅途 "+game.format_time(game.elapsed)+"  /  记忆 %d/18"%game.relics,10,T.MUTED)
	_spacer(menu)
	default_button = _button(menu,("从中继站重试" if dead else "继续旅程") if _mobile() else ("从中继站重试   R" if dead else "继续旅程   ESC"),"respawn" if dead else "resume",true,31)
	if not dead: _button(menu,"旅途设置","settings",false,27)
	_button(menu,"返回标题","menu",false,27)
	_label(box,"安全进度会保留。看清出手预警，冲刺穿过攻击，抓住恢复期反击。",9,T.MUTED)

func _reward() -> void:
	var box: VBoxContainer = _modal(594,316)
	_header(box,"SALVAGED MODULES / 守卫核心回收","选择装配组件")
	_label(box,"回收自熔炉看守的三件组件，只能稳定装配一件。选定后接通苍穹航线。",10,T.MUTED)
	var cards: HBoxContainer = _hbox(box,10)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index: int in range(3):
		var card: PanelContainer = _panel(cards)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var accent: Color = T.TEAL if index==2 else T.GOLD
		card.add_theme_stylebox_override("panel",T.module_frame())
		var column: VBoxContainer = _vbox(card,3)
		_label(column,["M-01 / 近战组件","V-02 / 生存组件","P-03 / 远程组件"][index],9,accent)
		var art: Control = _item_art(column,["blade","vital","pulse"][index],accent)
		_label(column,["锋芒 · 合金刃","余温 · 储能芯","回响 · 脉冲器"][index],16)
		_label(column,["让磨损的刀刃，再亮一次。","留一点温度，穿过暴风雨。","把沉默的电流，变成回应。"][index],9,T.MUTED)
		var before: int = 100+game.damage_bonus*15 if index==0 else game.player.max_health if index==1 else 100+game.pulse_bonus*12
		var after: int = mini(130,before+15) if index==0 else before+(1 if game.bonus_health<1 else 0) if index==1 else mini(124,before+12)
		_label(column,("近战  %d%% → %d%%" if index==0 else "生命  %d → %d 格" if index==1 else "脉冲  %d%% → %d%%")%[before,after],11,accent)
		_label(column,"单次生命扩容" if index==1 else "与工坊共享两级上限",8,T.MUTED)
		_spacer(column)
		var capped: bool = game.damage_bonus>=2 if index==0 else game.bonus_health>=1 if index==1 else game.pulse_bonus>=2
		var button: Button = _button(column,"已达上限" if capped else "%d  选择核心"%(index+1),"upgrade"+str(index),false,28)
		button.disabled = capped
		button.focus_entered.connect(func() -> void: _highlight_module(card,art,accent,true))
		button.focus_exited.connect(func() -> void: _highlight_module(card,art,accent,false))
		button.mouse_entered.connect(func() -> void: _highlight_module(card,art,accent,true))
		button.mouse_exited.connect(func() -> void: _highlight_module(card,art,accent,button.has_focus()))
		if not capped and not is_instance_valid(default_button): default_button = button
	if not is_instance_valid(default_button): default_button = _button(box,"组件均已装满 · 继续航程","upgrade1",true,28)

func _highlight_module(card: PanelContainer,art: Control,accent: Color,active: bool) -> void:
	art.selected = active
	card.add_theme_stylebox_override("panel",T.module_frame(active))

func _ending() -> void:
	var box: VBoxContainer = _modal(508,294)
	_header(box,"DELIVERY COMPLETE / 长路尽头","今夜，仍有光。")
	_label(box,"你把最后的火种，交给了等待黎明的人。",12,T.MUTED)
	var stats: HBoxContainer = _hbox(box,16)
	for entry: Array in [["旅途用时",game.format_time(game.elapsed)],["记忆碎片","%d / 18"%game.relics],["传递评分",str(game.run_score)]]:
		var column: VBoxContainer = _vbox(stats,3)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(column,entry[0],10,T.MUTED)
		_label(column,entry[1],24,T.GOLD)
	_label(box,"击败 %d 名守卫  ·  重试 %d 次  ·  最佳 %d"%[game.total_kills,game.deaths,game.best_score],10,T.TEAL)
	_spacer(box)
	var row: HBoxContainer = _hbox(box)
	_button(row,"再送一次火种","start",true,32).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row,"返回标题","menu",false,32).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _help() -> void:
	if _mobile():
		_mobile_help()
		return
	var box: VBoxContainer = _modal(548,302)
	_header(box,"COURIER FIELD GUIDE / 操作与生存","信使手册")
	var columns: HBoxContainer = _hbox(box,20)
	for index: int in range(2):
		var column: VBoxContainer = _vbox(columns,6)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c: Node = game.controls
		var entries: Array = [[c.prompt("move_left")+" / "+c.prompt("move_right"),"左右移动"],[c.prompt("jump"),"跳跃 · 空中可二段跳"],[c.prompt("attack"),"长按自动三连斩"],[c.prompt("pulse"),"能量波 · 辅助瞄准"]] if index==0 else [[c.prompt("dash")+" / "+c.prompt("parry"),"无敌冲刺 / 弹反"],[c.prompt("heal")+" / "+c.prompt("burst"),"修复两格 / 满蓄能爆发"],[c.prompt("interact")+" / "+c.prompt("journal"),"机关与交互 / 世界地图"],["↓ + "+c.prompt("jump"),"向下穿过薄平台"]]
		for entry: Array in entries:
			var row: HBoxContainer = _hbox(column,6)
			_label(row,entry[0],9,T.GOLD).custom_minimum_size.x = 103
			_label(row,entry[1],9,T.PAPER)
	_label(box,"近战与弹反积累共鸣：60 点亮支路中继，100 释放爆发。\n单槽装配可免费更换；重装守卫可以弹反或绕后。",10,T.MUTED)
	_spacer(box)
	var footer: HBoxContainer = _hbox(box)
	_button(footer,"守卫档案","bestiary",false,30)
	_spacer(footer,false)
	default_button = _button(footer,"明白了，继续前行","help",true,30)

func _journal() -> void:
	var box: VBoxContainer = _modal(594,316)
	var header: HBoxContainer = _header(box,"LOCAL SURVEY / 区域路线",game.chapter_names[game.chapter])
	for entry: Array in [["全图","map_all"],["定位","map_center"],["−","map_minus"],["+","map_plus"]]:
		var control: Button = _button(header,entry[0],entry[1],false,24)
		control.add_theme_font_size_override("font_size",10)
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var map: Control = SECTOR_MAP.new()
	map.game = game
	map.custom_minimum_size = Vector2(0,142)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(map)
	fields.area_map = map
	_label(box,"● 当前位置   ◇ 目标   青色中继站   金色补给 / 机关   巡逻可绕行",8,T.TEAL)
	_label(box,_objective()+"  ·  "+game.guide.direction(game.guide.current()),11,T.GOLD)
	var footer: HBoxContainer = _hbox(box)
	_label(footer,"单指拖动平移 · ＋ / − 缩放\n轻触顶端缩略线可快速定位" if _mobile() else "LB / RB 平移 · 方向键选择缩放按钮\nA 确认 · B / RS 返回" if game.controls.pad_active else "拖动 / A·D 平移 · 滚轮 / ± 缩放\n点击顶端缩略线可快速定位",8,T.MUTED)
	_spacer(footer,false)
	default_button = _button(footer,("继续旅途" if _mobile() else "继续旅途   C / ESC") if game.campaign.local_return=="playing" else "返回世界地图","local_back",true,28)

func _bestiary() -> void:
	_veil(0.98)
	var box: VBoxContainer = _vbox(_margin(screen,20),8)
	_header(box,"GUARDIAN ARCHIVE / 敌人识别","看清对手，再向前一步")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",9)
	grid.add_theme_constant_override("v_separation",9)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	var roster: Array = [["scout","裂轨侦察机","快速突进，弹反可中断"],["guard","重装履带机","蓄力后震击，跳跃躲开"],["sentry","线圈哨炮","三连齐射，靠近或反射"],["drone","巡航无人机","保持距离，能量波迎击"],["boss","熔炉看守","重击后暴露，抓住恢复期"],["tempest","风暴织机","看地面雷标，俯冲后反击"]]
	for entry: Array in roster:
		var card: PanelContainer = _panel(grid)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column: VBoxContainer = _vbox(card,1)
		var portrait: Control = PORTRAIT.new()
		portrait.family = entry[0]
		portrait.custom_minimum_size = Vector2(160,49)
		column.add_child(portrait)
		_label(column,entry[1],13,T.GOLD)
		_label(column,entry[2],9,T.MUTED)
	default_button = _button(box,"返回标题","bestiary_back",true,28)

func _credits() -> void:
	var box: VBoxContainer = _modal(554,304)
	_header(box,"EMBER RELAY / THE CREATOR","余烬信使 · 主创名单")
	var credit: ConfigFile = ConfigFile.new()
	credit.load("res://credits.cfg")
	var creator: String = str(credit.get_value("credits","lead_creator",""))
	var panel: PanelContainer = _panel(box)
	panel.add_theme_stylebox_override("panel",T.flat(Color("10222b"),Color("6b7360"),1,14))
	var column: VBoxContainer = _vbox(panel,5)
	_label(column,"主要创作人 / 创意方向与制作统筹",10,T.TEAL)
	fields.lead_creator = _label(column,creator if not creator.is_empty() else "主创署名待确认",28,T.GOLD)
	_label(column,"项目发起 · 世界与玩法方向 · 内容决策 · 最终验收",10,T.PAPER)
	_label(box,"把最后的火种，送到仍在等待黎明的人手中。",12,T.MUTED)
	_spacer(box)
	var row: HBoxContainer = _hbox(box)
	_button(row,"素材与工具致谢","asset_credits",false,30).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	default_button = _button(row,"返回标题","credits_back",true,30)

func _asset_credits() -> void:
	var box: VBoxContainer = _modal(574,318)
	_header(box,"ASSET ACKNOWLEDGMENTS / LICENSES","素材与工具致谢")
	var entries: Array = [["角色 / 遗迹 / 远景","Luis Zuno · Ansimuz / CC BY 3.0、CC0"],["机器人动画","Baldur · Foozle / Sci-fi Lab Droids · CC0"],["机甲动画","aimen23b · Foozle / Mecha Boss · CC0"],["界面材质","Kenney / UI Pack Sci-Fi · CC0"],["道具像素图","Adam Saltsman / Sci Fi Inventory · Public domain"],["音乐","Pascal Belisle / Level 04 · Sci-fi Platformer 02"],["工业图集 / 引擎","Robert · 0x72 / CC0     Godot Engine / MIT"]]
	for entry: Array in entries:
		var row: HBoxContainer = _hbox(box)
		_label(row,entry[0],10,T.TEAL).custom_minimum_size.x = 103
		_label(row,entry[1],10,T.PAPER)
	_label(box,"字体：Noto Sans SC / 站酷庆科黄油体 · SIL OFL 1.1",9,T.MUTED)
	_label(box,"感谢上述素材提供者。许可、来源与改动说明随游戏分发于「素材鸣谢」。",9,T.MUTED)
	_spacer(box)
	default_button = _button(box,"返回主创名单","credits_return",true,28)

func consume_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var key: int = event.physical_keycode
	if game.state=="journal" and fields.has("area_map"):
		if key in [KEY_A,KEY_D]: fields.area_map.pan(-1 if key==KEY_A else 1); return true
		if key in [KEY_EQUAL,KEY_KP_ADD]: fields.area_map.zoom_by(0.75); return true
		if key in [KEY_MINUS,KEY_KP_SUBTRACT]: fields.area_map.zoom_by(1.33); return true
		if key==KEY_HOME: fields.area_map.center_on_player(); return true
	if game.state in ["playing","boss_intro"]: return false
	if key==KEY_ESCAPE:
		match game.state:
			"menu": game.menu_help = false
			"paused", "shop": game.state = "playing"
			"dead", "victory", "credits", "bestiary": game.return_to_menu()
			"asset_credits": game.state = "credits"
			"settings":
				game.director.save_settings()
				game.state = game.director.settings_return
			"controls": game.controls.capture_action = ""; game.state = "settings"
			"attunement": game.state = "playing"
			"world_map": game.campaign.action("atlas_back")
			"journal": game.campaign.action("local_back")
		return true
	if event.is_action_pressed("journal") and game.state in ["world_map","journal"]:
		game.state = "playing" if is_instance_valid(game.player) else "menu"
		return true
	if event.is_action_pressed("local_map") and game.state=="journal":
		game.campaign.action("local_back")
		return true
	if key in [KEY_1,KEY_2] and game.state=="world_map":
		game.campaign.selected = 0 if key==KEY_1 else 1
		_queue_refresh()
		return true
	if key in [KEY_1,KEY_2,KEY_3] and game.state=="upgrade":
		var index: int = key-KEY_1
		var button: Button = actions.get("upgrade"+str(index))
		if is_instance_valid(button) and not button.disabled: game.choose_upgrade(index)
		return true
	if key==KEY_R and game.state=="dead":
		game.respawn()
		return true
	if key in [KEY_1,KEY_2,KEY_3] and game.state=="attunement":
		game.flame.equip(key-KEY_1)
		return true
	return false

func _mobile_hud() -> void:
	if not is_instance_valid(game.player): return
	fields.mobile_hud = true
	var top: MarginContainer = _margin(screen,10)
	top.anchor_bottom = 0; top.offset_bottom = 70
	top.add_theme_constant_override("margin_top",6)
	top.add_theme_constant_override("margin_bottom",0)
	var row: HBoxContainer = _hbox(top,14)
	var info: VBoxContainer = _vbox(row,3)
	info.custom_minimum_size.x = 140
	var hp: HBoxContainer = _hbox(info,5)
	_signal_art(hp,"signal-badge",Vector2(18,23))
	_label(hp,"信使 07",11,T.PAPER)
	_spacer(hp,false)
	fields.hp_text = _label(hp,"",11,T.GOLD)
	fields.hp = SEGMENTED_METER.new()
	fields.hp.custom_minimum_size = Vector2(140,5)
	info.add_child(fields.hp)
	fields.energy = _bar(info,T.TEAL,3)
	var resources: HBoxContainer = _hbox(info,5)
	_icon(resources,"ember",12,T.GOLD)
	fields.embers = _label(resources,"",11,T.PAPER)
	_icon(resources,"memory",12,T.TEAL)
	fields.memories = _label(resources,"",11,T.MUTED)
	fields.mobile_supplies = _label(info,"",11,T.MUTED)
	var objective: VBoxContainer = _vbox(row,3)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(objective,"%02d / %s"%[game.chapter+1,game.chapter_names[game.chapter]],12,T.PAPER)
	fields.goal = _label(objective,"",11,T.TEAL,true)
	fields.goal.custom_minimum_size.x = 150
	# Reserve the top-right thumb targets owned by TouchControls.
	var reserved: Control = Control.new(); reserved.custom_minimum_size.x = 88; row.add_child(reserved)
	fields.lesson = _label(screen,"",11,T.MUTED,true)
	fields.lesson.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	fields.lesson.offset_left = 170; fields.lesson.offset_right = -100
	fields.lesson.offset_top = 64; fields.lesson.offset_bottom = 84
	fields.lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_holder: CenterContainer = CenterContainer.new()
	boss_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_holder.offset_top = 84; boss_holder.offset_bottom = 113
	screen.add_child(boss_holder); fields.boss_holder = boss_holder
	var boss_box: VBoxContainer = _vbox(boss_holder,3)
	boss_box.custom_minimum_size.x = 260
	fields.boss_name = _label(boss_box,"",11,T.GOLD)
	fields.boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields.boss_hp = _bar(boss_box,T.GOLD,5)
	fields.combo = _label(screen,"",14,T.GOLD)
	fields.combo.position = Vector2(16,84)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 86; center.offset_bottom = 139
	screen.add_child(center)
	toast_box = _panel(center); toast_box.custom_minimum_size.x = 308
	toast_box.visible = false
	var words: VBoxContainer = _vbox(toast_box,2)
	fields.toast_title = _label(words,"投递处通讯 · 触摸攻击收起",11,T.TEAL)
	fields.toast = _label(words,"",12,T.PAPER,true)
	fields.toast.custom_minimum_size.x = 284
	fields.toast.custom_minimum_size.y = 24
	_set_passive(screen)
	if game.state=="boss_intro":
		var center_intro: CenterContainer = CenterContainer.new()
		center_intro.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		center_intro.offset_top = 125
		center_intro.offset_bottom = 225
		screen.add_child(center_intro)
		var box: VBoxContainer = _vbox(_panel(center_intro),6)
		_display(box,game.campaign.BOSSES[game.chapter/3],28)
		var skip: Button = _button(box,"开始交锋","skip_mobile_intro",true,36)
		skip.pressed.connect(func() -> void: game.director.boss_intro = 0)

func _sync_mobile_stats() -> void:
	if not is_instance_valid(game.player): return
	var p: Node = game.player
	fields.hp.max_value = p.max_health; fields.hp.segments = p.max_health; fields.hp.value = p.health
	fields.hp_text.text = "%d / %d"%[p.health,p.max_health]
	fields.energy.value = p.energy
	fields.embers.text = str(game.embers)
	fields.memories.text = "%d/18"%game.relics
	fields.mobile_supplies.text = "修复×%d · 共鸣 %d%%"%[game.director.potions,roundi(game.director.focus)]
	var target: Dictionary = game.guide.current()
	var objective: String = ("水力桥通电 · 继续向东" if game.presentation.circuit_on else "穿过东侧检修口") if game.chapter==1 else _objective()
	fields.goal.text = objective+"\n"+game.guide.direction(target).replace("E ","交互 ").replace("C 地图","轻触地图")
	fields.lesson.text = "左侧移动 · 右侧攻击 / 跳跃" if not game.flame.lesson_text.is_empty() else ""
	fields.lesson.visible = not fields.lesson.text.is_empty() and not game.boss_awake
	fields.combo.text = "%02d 连击"%game.director.combo if game.director.combo>=3 else ""
	fields.boss_holder.visible = game.boss_awake and not game.boss_defeated and is_instance_valid(game.boss)
	if fields.boss_holder.visible:
		fields.boss_name.text = game.campaign.BOSSES[game.chapter/3]
		fields.boss_hp.max_value = game.boss.max_health; fields.boss_hp.value = game.boss.health
	if game.boss_awake or game.director.active_arena>=0: _dismiss_toast()

func _mobile_settings() -> void:
	var box: VBoxContainer = _modal(550,318)
	box.add_theme_constant_override("separation",6)
	_header(box,"PREFERENCES","旅途设置")
	var audio_row: HBoxContainer = _hbox(box)
	_label(audio_row,"音量",12)
	var slider: HSlider = HSlider.new()
	slider.name = "VolumeSlider"; slider.min_value = 0; slider.max_value = 1; slider.step = 0.05
	slider.value = game.director.volume; slider.custom_minimum_size = Vector2(180,34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		game.director.volume = value; game.director.apply_volume())
	slider.drag_ended.connect(func(_changed: bool) -> void: game.director.save_settings())
	var shake_toggle: CheckButton = CheckButton.new()
	shake_toggle.text = "命中时镜头震动"; shake_toggle.button_pressed = game.director.shake_enabled
	shake_toggle.custom_minimum_size.y = 34; box.add_child(shake_toggle)
	shake_toggle.toggled.connect(func(value: bool) -> void:
		game.director.shake_enabled = value; game.director.save_settings())
	var difficulty: OptionButton = OptionButton.new()
	difficulty.name = "DifficultySelector"; difficulty.custom_minimum_size.y = 34
	for entry: String in ["漫游 · 更多生命与容错","标准 · 观察预警与反击","挑战 · 承受更高伤害"]: difficulty.add_item(entry)
	difficulty.select(game.director.difficulty); box.add_child(difficulty)
	difficulty.item_selected.connect(func(index: int) -> void:
		game.director.difficulty = index; game.director.save_settings())
	_button(box,"触控布局与操作说明","controls",false,34)
	_label(box,"横屏游玩 · 系统返回键可暂停 · 成长上限与电脑版一致",11,T.MUTED,true)
	_spacer(box)
	default_button = _button(box,"保存并返回","settings_back",true,36)

func _mobile_controls() -> void:
	var box: VBoxContainer = _modal(570,326)
	box.add_theme_constant_override("separation",5)
	_header(box,"TOUCH CONTROLS","触控操作")
	_label(box,"左侧摇杆移动 · 向下推＋跳跃穿平台\n长按近战三连斩 · 空中再按跳跃二段跳",12,T.PAPER,true)
	_label(box,"射击消耗能量 · 冲刺躲避 · 弹反抓住敌人出手\n修复恢复生命 · 共鸣蓄满释放爆发 · 靠近机关点交互",11,T.MUTED,true)
	var sizes: HBoxContainer = _hbox(box)
	_label(sizes,"按键大小",12)
	for entry: Array in [["标准",1.0],["偏大",1.12]]:
		var b: Button = _button(sizes,entry[0],"touch_size_"+str(entry[1]),false,34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			game.controls.touch_scale = entry[1]; game.controls.save_config(); game.touch_controls.relayout())
	var row: HBoxContainer = _hbox(box)
	_label(row,"按键透明度",12)
	var opacity: HSlider = HSlider.new()
	opacity.name = "TouchOpacity"; opacity.min_value = 0.35; opacity.max_value = 0.9; opacity.step = 0.05
	opacity.value = game.controls.touch_opacity; opacity.custom_minimum_size = Vector2(220,34)
	opacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(opacity)
	opacity.value_changed.connect(func(value: float) -> void:
		game.controls.touch_opacity = value; game.touch_controls.relayout())
	opacity.drag_ended.connect(func(_changed: bool) -> void: game.controls.save_config())
	_label(box,"支持多指同时操作；暂停、切到后台会松开所有按键。",11,T.TEAL,true)
	_spacer(box)
	default_button = _button(box,"返回设置","controls_back",true,36)

func _mobile_help() -> void:
	var box: VBoxContainer = _modal(560,310)
	_header(box,"FIELD GUIDE","信使手册")
	_label(box,"左拇指移动，右拇指战斗。",17,T.GOLD)
	_label(box,"长按连斩：自动接续三段近战。\n跳跃：轻触起跳，空中再按完成二段跳。\n冲刺躲避预警，弹反抓住敌人出手的瞬间。",12,T.PAPER,true)
	_label(box,"射击消耗能量，松手自动恢复；修复恢复两格生命。\n近战与弹反积累共鸣：60 点亮中继，100 释放爆发。\n靠近机关、补给箱与中继门后轻触「交互」。",12,T.MUTED,true)
	_spacer(box)
	_label(box,"顶部地图查看目标；暂停 → 设置可调整按键大小和透明度。",11,T.TEAL,true)
	default_button = _button(box,"明白了，继续前行","help",true,36)
