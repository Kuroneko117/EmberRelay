extends Control
## The terminal's native Control screens and event-driven HUD.
const T = preload("res://scripts/ui_theme.gd")
const REGION_ART = preload("res://scripts/region_art.gd")
const PORTRAIT = preload("res://scripts/unit_portrait.gd")
const SECTOR_MAP = preload("res://scripts/sector_map.gd")
const WORLD_ROUTE = preload("res://scripts/world_route.gd")
const ITEM_DISPLAY = preload("res://scripts/item_display.gd")
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
	_refresh()

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
	node.add_theme_font_size_override("font_size",font_size)
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
	var node: Button = Button.new()
	node.name = "Action_"+action
	node.text = text
	node.custom_minimum_size = Vector2(0,height)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		node.add_theme_stylebox_override("normal",T.material("button-active"))
		node.add_theme_color_override("font_color",Color("fff0d0"))
	node.pressed.connect(_pressed.bind(action))
	node.focus_entered.connect(_focus_sound)
	parent.add_child(node)
	actions[action] = node
	if primary and not is_instance_valid(default_button): default_button = node
	return node

func _pressed(action: String) -> void:
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
	panel.custom_minimum_size = Vector2(width,height)
	return _vbox(panel,8)

func _header(parent: Node,tag: String,title: String) -> HBoxContainer:
	var row: HBoxContainer = _hbox(parent)
	var column: VBoxContainer = _vbox(row,2)
	_label(column,tag,9,T.TEAL)
	_label(column,title,23)
	_spacer(row,false)
	return row

func _title() -> void:
	var row: HBoxContainer = _hbox(_margin(screen,26))
	var left: VBoxContainer = _vbox(row,4)
	left.custom_minimum_size.x = 260
	_label(left,"LIGHTHOUSE  /  信使终端 07",9,T.TEAL)
	_label(left,"余烬信使",40)
	_label(left,"E M B E R   R E L A Y",16,T.GOLD)
	_label(left,"长夜将尽，沿着余光继续前行。",11,T.PAPER)
	_label(left,"两条航线 · 六处遗迹 · 十八段记忆",9,T.MUTED)
	_spacer(left)
	var first: Button = _button(left,"继续旅程    →" if game.director.saved_available else "展开航线    →","continue" if game.director.saved_available else "start",true,34)
	first.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var links: HBoxContainer = _hbox(left,5)
	for info: Array in [["信使手册","help"],["守卫档案","bestiary"],["设置","settings"]]:
		var control: Button = _button(links,info[0],info[1],false,25)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.add_theme_font_size_override("font_size",10)
	if game.director.saved_available: _button(left,"重新点燃 · 开始新旅途","start",false,24)
	var footer: HBoxContainer = _hbox(left)
	_button(footer,"主创与致谢","credits",false,23).add_theme_font_size_override("font_size",9)
	_button(footer,"离开","quit",false,23).add_theme_font_size_override("font_size",9)
	_spacer(row,false)
	var right: VBoxContainer = _vbox(row)
	right.alignment = BoxContainer.ALIGNMENT_END
	_label(right,"THE LIVING EMBER / 06",9,T.TEAL)
	_label(right,"信号在线  ·  最佳 %06d"%game.best_score,9,T.PAPER)

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
	_label(footer,"1 / 2 选择航线\n已探索节点可回访",8,T.MUTED)
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
	if not is_instance_valid(game.player): return
	var top: MarginContainer = _margin(screen,12)
	top.anchor_bottom = 0
	top.offset_bottom = 66
	var row: HBoxContainer = _hbox(top,10)
	var identity: PanelContainer = _panel(row)
	identity.custom_minimum_size.x = 181
	identity.add_theme_stylebox_override("panel",T.flat(Color(0.035,0.08,0.10,0.90),Color("476464"),1))
	var info: HBoxContainer = _hbox(identity,4)
	var avatar: TextureRect = TextureRect.new()
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = preload("res://assets/art/player-idle.png")
	texture.region = Rect2(24,15,29,50)
	avatar.texture = texture
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(26,37)
	info.add_child(avatar)
	var health: VBoxContainer = _vbox(info,2)
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp_row: HBoxContainer = _hbox(health)
	_label(hp_row,"信使 07",9,T.MUTED)
	_spacer(hp_row,false)
	fields.hp_text = _label(hp_row,"",11,T.GOLD)
	fields.hp = _bar(health,T.GOLD,6)
	fields.energy = _bar(health,T.TEAL,3)
	var resources: VBoxContainer = _vbox(row,4)
	var count_row: HBoxContainer = _hbox(resources,5)
	_icon(count_row,"ember",18,T.GOLD)
	fields.embers = _label(count_row,"00",16,T.GOLD)
	_icon(count_row,"memory",15,T.TEAL)
	fields.memories = _label(count_row,"0/18",10,T.PAPER)
	fields.clock = _label(resources,"",9,T.MUTED)
	_spacer(row,false)
	var goal_panel: PanelContainer = _panel(row)
	goal_panel.custom_minimum_size.x = 198
	goal_panel.add_theme_stylebox_override("panel",T.flat(Color(0.035,0.08,0.1,0.9)))
	var goal: VBoxContainer = _vbox(goal_panel,1)
	_label(goal,"%02d  /  %s"%[game.chapter/3+1,game.chapter_names[game.chapter]],15,T.PAPER)
	fields.goal = _label(goal,"",9,T.TEAL)
	var bottom: MarginContainer = _margin(screen,12)
	bottom.anchor_top = 1
	bottom.offset_top = -52
	var lower: HBoxContainer = _hbox(bottom,5)
	for info_key: Array in [["Q","parry"],["F","repair"],["R","burst"]]:
		var slot: PanelContainer = _panel(lower)
		slot.custom_minimum_size = Vector2(39,37)
		slot.add_theme_stylebox_override("panel",T.material("slot"))
		var box: VBoxContainer = _vbox(slot,0)
		_icon(box,info_key[1],17,T.TEAL if info_key[0]=="Q" else T.GOLD)
		var key: Label = _label(box,info_key[0],8,T.PAPER)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if info_key[0]=="F": fields.repairs = key
		if info_key[0]=="R": fields.burst = key
		if info_key[0]=="Q": fields.parry = key
	var gauge: VBoxContainer = _vbox(lower,3)
	gauge.custom_minimum_size.x = 70
	gauge.alignment = BoxContainer.ALIGNMENT_CENTER
	fields.flame_status = _label(gauge,"余烬共鸣",8,T.MUTED)
	fields.focus = _bar(gauge,T.GOLD,4)
	fields.equipped = _label(gauge,"",8,T.TEAL)
	_spacer(lower,false)
	fields.controls_hint = _label(lower,"",9,T.MUTED)
	var lesson: Label = _label(screen,"",9,T.PAPER)
	lesson.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lesson.offset_left = 80
	lesson.offset_right = -80
	lesson.offset_top = -57
	lesson.offset_bottom = -42
	lesson.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lesson.add_theme_stylebox_override("normal",T.flat(Color(0.025,0.06,0.08,0.88)))
	fields.lesson = lesson
	var boss_holder: CenterContainer = CenterContainer.new()
	boss_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_holder.offset_top = 68
	boss_holder.offset_bottom = 102
	screen.add_child(boss_holder)
	fields.boss_holder = boss_holder
	var boss_box: VBoxContainer = _vbox(boss_holder,4)
	boss_box.custom_minimum_size.x = 300
	fields.boss_name = _label(boss_box,"",10,T.GOLD)
	fields.boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields.boss_hp = _bar(boss_box,T.GOLD,5)
	fields.combo = _label(screen,"",14,T.GOLD)
	fields.combo.position = Vector2(18,70)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 79
	center.offset_bottom = 133
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
		_label(text,"GUARDIAN PROTOCOL / 终点守卫",9,T.TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(text,game.campaign.BOSSES[game.chapter/3],25,T.PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(text,"ENTER 跳过登场",8,T.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_passive(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _set_passive(child)

func _sync_stats() -> void:
	if building or fields.is_empty() or not is_inside_tree(): return
	if fields.has("hp") and is_instance_valid(game.player):
		var p: Node = game.player
		fields.hp.max_value = p.max_health
		fields.hp.value = p.health
		fields.hp_text.text = "%d / %d"%[p.health,p.max_health]
		fields.energy.value = p.energy
		fields.focus.value = game.director.focus
		fields.embers.text = "%02d"%game.embers
		fields.memories.text = "%d/18"%game.relics
		fields.clock.text = game.format_time(game.elapsed)
		fields.repairs.text = "%s ×%d"%[game.controls.prompt("heal"),game.director.potions]
		fields.parry.text = game.controls.prompt("parry")
		fields.burst.text = game.controls.prompt("burst")+(" 就绪" if game.director.focus>=100 else "")
		fields.flame_status.text = "共鸣 %d"%int(game.director.focus)+(" · 返流" if game.flame.charged>0 else "")
		fields.equipped.text = game.flame.NAMES[game.flame.module] if game.flame.module>=0 else "支路中继 / 待装配"
		fields.controls_hint.text = "%s 斩  %s 射  %s 冲刺\n%s 区域图  %s 航线"%[game.controls.prompt("attack"),game.controls.prompt("pulse"),game.controls.prompt("dash"),game.controls.prompt("local_map"),game.controls.prompt("journal")]
		fields.lesson.text = game.flame.lesson_text
		fields.lesson.visible = not game.flame.lesson_text.is_empty()
		var target: Dictionary = game.guide.current()
		fields.goal.text = _objective()+"\n"+game.guide.direction(target).replace("E ",game.controls.prompt("interact")+" ").replace("C ",game.controls.prompt("local_map")+" ")
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
	if not is_instance_valid(toast_box) or game.state!="playing": return
	# Held attacks and active battles always keep the arena free of message panels.
	if Input.is_action_pressed("attack") or Input.is_action_pressed("pulse"):
		game.dismiss_messages()
		return
	if (game.boss_awake and not game.boss_defeated) or game.director.active_arena>=0:
		_dismiss_toast()
		return
	if is_instance_valid(toast_tween): toast_tween.kill()
	fields.toast_title.text = "灯塔 / 旅途信号  ·  攻击键收起"
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
	if is_instance_valid(toast_box): fields.toast_title.text = "灯塔 / 无线电接入  ·  攻击键收起"

func _shop() -> void:
	var box: VBoxContainer = _modal(582,300)
	var head: HBoxContainer = _header(box,"RELAY 07 / MAINTENANCE","中继工坊")
	_icon(head,"ember",21,T.GOLD)
	fields.shop_currency = _label(head,"",17,T.GOLD)
	var cards: HBoxContainer = _hbox(box,9)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index: int in range(3):
		var card: PanelContainer = _panel(cards)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",T.flat(Color("10222b"),Color("3c565d"),1,8))
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
	var box: VBoxContainer = _modal(594,316)
	_header(box,"IGNITION / OPTIONAL RELAY","把火种留给哪一种可能")
	var on: bool = game.flame.lit.has(game.chapter)
	_label(box,"中继已点亮 · 更换免费" if on else "接通消耗 60 共鸣，选定后扣除 · 也可以保留共鸣用于 100 点爆发",10,T.TEAL)
	var cards: HBoxContainer = _hbox(box,9)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index: int in range(3):
		var card: PanelContainer = _panel(cards)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",T.flat(Color("10222b"),T.TEAL if game.flame.module==index else Color("3c565d"),1,8))
		var column: VBoxContainer = _vbox(card,4)
		_label(column,["01 / 弹反反击","02 / 连斩破阵","03 / 空中机动"][index],8,T.MUTED)
		_item_art(column,game.flame.ITEMS[index],T.TEAL if index==0 else T.GOLD).custom_minimum_size.y = 53
		_label(column,game.flame.NAMES[index],17)
		_label(column,game.flame.DETAILS[index],9,T.MUTED)
		_spacer(column)
		_button(column,"已装配 · 继续" if game.flame.module==index else "%d 装配"%(index+1),"attune_"+str(index),index==0,28)
	var foot: HBoxContainer = _hbox(box)
	_label(foot,"单槽装配。"+("接通后关闭蒸汽，升起排水步道。" if game.chapter==1 else "点亮的中继可免费改装。"),9,T.MUTED)
	_spacer(foot,false)
	_button(foot,"暂不接通","close",false,27)

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
	default_button = _button(menu,"从中继站重试   R" if dead else "继续旅程   ESC","respawn" if dead else "resume",true,31)
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
		card.add_theme_stylebox_override("panel",T.flat(Color("10222b"),Color("3c565d"),1,9))
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
	card.add_theme_stylebox_override("panel",T.flat(Color("162d34") if active else Color("10222b"),accent if active else Color("3c565d"),1,9))

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
	default_button = _button(box,"明白了，继续前行","help",true,30)

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
	_label(box,"● 当前位置   ◇ 目标   青色中继站   金色补给 / 机关   暗红未解封锁",8,T.TEAL)
	_label(box,_objective()+"  ·  "+game.guide.direction(game.guide.current()),11,T.GOLD)
	var footer: HBoxContainer = _hbox(box)
	_label(footer,"LB / RB 平移 · 方向键选择缩放按钮\nA 确认 · B / RS 返回" if game.controls.pad_active else "拖动 / A·D 平移 · 滚轮 / ± 缩放\n点击顶端缩略线可快速定位",8,T.MUTED)
	_spacer(footer,false)
	default_button = _button(footer,"继续旅途   C / ESC" if game.campaign.local_return=="playing" else "返回世界地图","local_back",true,28)

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
