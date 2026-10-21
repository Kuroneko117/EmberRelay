extends Node2D
## Encounter direction, combat rewards, campaign persistence and environmental life.
const TEAL = Color("79e1cd")
const AMBER = Color("ffbd77")
const RED = Color("ef6b70")
const FONT = preload("res://assets/ui_font.ttc")
var game: Node
var combo: int = 0:
	set(value):
		if combo==value: return
		combo = value
		if is_instance_valid(game): game.stats_changed.emit()
var combo_time: float = 0
var focus: float = 0:
	set(value):
		if focus==value: return
		focus = value
		if is_instance_valid(game): game.stats_changed.emit()
var potions: int = 2:
	set(value):
		if potions==value: return
		potions = value
		if is_instance_valid(game): game.stats_changed.emit()
var rings: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var arenas: Array[Dictionary] = []
var arena_members: Array[Node] = []
var active_arena: int = -1:
	set(value):
		if active_arena==value: return
		active_arena = value
		if is_instance_valid(game): game.stats_changed.emit()
var wave: int = 0:
	set(value):
		if wave==value: return
		wave = value
		if is_instance_valid(game): game.stats_changed.emit()
var wave_delay: float = 0
var cleared: int = 0:
	set(value):
		if cleared==value: return
		cleared = value
		if is_instance_valid(game): game.stats_changed.emit()
var radio: String = ""
var radio_time: float = 0
var boss_intro: float = 0
var restoring: bool = false
var settings_return: String = "menu"
var volume: float = 0.8
var shake_enabled: bool = true
var difficulty: int = 1
var tips_seen: Dictionary = {}
var weather_time: float = 0
var hazard_time: float = 0
var secrets: int = 0
var saved_available: bool = false
var storage_override: String = ""

func _ready() -> void:
	z_index = 18
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path("settings.cfg"))==OK:
		volume = float(cfg.get_value("settings","volume",0.8))
		shake_enabled = bool(cfg.get_value("settings","shake",true))
		difficulty = int(cfg.get_value("settings","difficulty",1))
	apply_volume()
	saved_available = FileAccess.file_exists(path("journey.cfg"))

func configure() -> void:
	combo = 0
	combo_time = 0
	potions = 2
	rings.clear()
	chests.clear()
	arenas.clear()
	arena_members.clear()
	active_arena = -1
	wave = 0
	wave_delay = 0
	cleared = 0
	boss_intro = 0
	hazard_time = 0
	if game.chapter%3 < 2:
		arenas = [{"left":800.0 if game.chapter==0 else 665.0,"right":1335.0,"done":false},
			{"left":1560.0 if game.chapter==0 else 1500.0,"right":2110.0 if game.chapter==0 else 1915.0,"done":false}]
	if game.chapter==3:
		arenas = [{"left":850.0,"right":1450.0,"done":false},{"left":1730.0,"right":2270.0,"done":false},{"left":2530.0,"right":3035.0,"done":false}]
	elif game.chapter==4:
		arenas = [{"left":800.0,"right":1350.0,"done":false},{"left":1550.0,"right":2240.0,"done":false},{"left":2440.0,"right":3030.0,"done":false}]
	var locations: Array = [[Vector2(493,204),Vector2(1420,193)],[Vector2(470,196),Vector2(2005,202)],[Vector2(588,204),Vector2(1270,248)],
		[Vector2(1185,185),Vector2(2120,151),Vector2(2970,152)],[Vector2(1320,157),Vector2(2090,139),Vector2(3550,182)],[Vector2(565,193),Vector2(1490,146),Vector2(2360,145)]][game.chapter]
	for pos: Vector2 in locations:
		chests.append({"pos":pos,"open":false})
	say(["这里是灯塔。信使，你脚下的路已经沉寂了很久。把火种带回来。",
		"管廊还有备用电力。留意蒸汽喷口，别让守卫截住你。",
		"那台机器的装甲仍然完整。等它的锤臂落下，再攻击暴露的炉心。",
		"先启动船坞入口地面的 P 号供电箱，靠近按 E。目标方向在右上角，C 打开区域地图。",
		"信标 1 在旧站台，信标 2 在右侧天线台。按 C 查看标记；跳上平台，靠近按 E。",
		"风暴织机还在等待投递。看清落雷，再抓住它俯冲落地的空隙。"][game.chapter])
	populate_patrols()
	queue_redraw()

func _process(delta: float) -> void:
	weather_time += delta
	if game.state=="boss_intro":
		boss_intro -= delta
		game.camera.position.x = lerpf(game.camera.position.x,game.campaign.boss_home().x,delta*3)
		if boss_intro<=0:
			game.state = "playing"
			game.player.invulnerable = 1
	if game.state=="playing":
		radio_time = maxf(0,radio_time-delta)
		combo_time = maxf(0,combo_time-delta)
		if combo_time<=0: combo = 0
		for i: int in range(rings.size()-1,-1,-1):
			rings[i].life -= delta
			if rings[i].life<=0: rings.remove_at(i)
	queue_redraw()

func tick(delta: float) -> void:
	if game.state!="playing" or game.hit_pause>0: return
	hazard_time += delta
	var p: Node = game.player
	if Input.is_action_just_pressed("heal"):
		if potions>0 and p.health<p.max_health:
			potions -= 1
			game.flame.mark("heal")
			p.health = mini(p.max_health,p.health+2)
			p.invulnerable = maxf(p.invulnerable,0.35)
			ring(p.position-Vector2(0,16),TEAL,55)
			game.audio.play_sfx("checkpoint")
			game.floating_number(p.position-Vector2(0,40),"修复 +2",TEAL)
		else: game.show_notice("生命已满" if p.health==p.max_health else "修复剂耗尽 · 中继站可补充")
	if Input.is_action_just_pressed("burst"):
		if focus>=100:
			game.flame.mark("burst")
			focus = 0
			p.invulnerable = 0.5
			ring(p.position-Vector2(0,18),AMBER,180)
			game.audio.play_sfx("burst")
			game.hit_pause = 0.09
			game.add_shake(8)
			for enemy: Node in game.enemies.duplicate():
				if is_instance_valid(enemy) and enemy.position.distance_to(p.position)<175:
					enemy.hurt(8*(1+mini(2,game.damage_bonus)*0.15),Vector2(signf(enemy.position.x-p.position.x)*290,-120))
					enemy.stun = 0.12 if enemy.kind in ["boss","tempest"] else 0.5
			for bullet: Dictionary in game.projectiles:
				if bullet.hostile and bullet.pos.distance_to(p.position)<200:
					bullet.hostile = false
					bullet.vel *= -1.6
					bullet.damage = 3
					bullet.color = TEAL
			game.show_notice("余烬爆发 · 击碎包围，反射弹幕")
		else: game.show_notice("攻击与弹反可以积蓄余烬 · 蓄满后按 R 爆发")
	for chest: Dictionary in chests:
		if not chest.open and p.position.distance_to(chest.pos)<42 and Input.is_action_just_pressed("interact"):
			chest.open = true
			secrets += 1
			game.embers += 6
			game.run_score += 150
			focus = minf(100,focus+12)
			ring(chest.pos-Vector2(0,10),AMBER,55)
			game.audio.play_sfx("chest")
			game.show_notice("补给箱：余烬 +6 / 蓄能 +12")
			save_campaign()
	if game.checkpoint_active and absf(p.position.x-game.checkpoint_x)<42 and p.position.y>250 and active_arena<0 and Input.is_action_just_pressed("interact"):
		game.state = "shop"
	if game.chapter==1:
		for x: float in [360.0,1555.0,2300.0]:
			var phase: float = fposmod(hazard_time+x*0.003,4.6)
			if not game.flame.lit.has(1) and phase>3.5 and absf(p.position.x-x)<15 and p.position.y>251:
				p.hurt(1,Vector2(x,300),80)

func populate_patrols() -> void:
	# Encounters exist in the world before arrival. No walls or repeated waves.
	for index: int in range(arenas.size()):
		var area: Dictionary = arenas[index]
		var types: Array = ["scout","scout"] if game.chapter==0 and index==0 else ["guard","drone"]
		if game.chapter==1 and index==0: types = ["guard","sentry"]
		if game.chapter>=3: types = ["guard","scout","drone"] if index%2==0 else ["sentry","scout"]
		for i: int in range(types.size()):
			var x: float = lerpf(area.left+90,area.right-90,float(i)/maxi(1,types.size()-1))
			var foe: Node = game._spawn_enemy(types[i],Vector2(x,210 if types[i]=="drone" else 292))
			foe.set_meta("patrol",index)
			foe.cooldown = 1.4

func patrol_killed(foe: Node) -> void:
	var index: int = int(foe.get_meta("patrol",-1))
	if index<0 or index>=arenas.size() or arenas[index].done: return
	for other: Node in game.enemies:
		if is_instance_valid(other) and not other.dead and int(other.get_meta("patrol",-1))==index: return
	arenas[index].done = true
	cleared += 1
	game.embers += 4
	game.flame.gain(18)
	game.floating_number(game.player.position-Vector2(0,48),"巡逻清除 · 共鸣 +18",TEAL)
	game.audio.play_sfx("checkpoint")
	save_campaign()

func hit(melee: bool=false) -> void:
	combo += 1
	combo_time = 3.2
	focus = minf(100,focus+(6 if melee else 1))
	game.hit_pause = maxf(game.hit_pause,0.035)

func parry(source: Vector2) -> void:
	game.flame.on_parry()
	focus = minf(100,focus+14)
	game.player.energy = minf(100,game.player.energy+14)
	game.player.invulnerable = 0.35
	game.hit_pause = 0.07
	ring(game.player.position-Vector2(0,18),TEAL,75)
	game.audio.play_sfx("parry")
	game.floating_number(game.player.position-Vector2(24,40),"完美弹反",TEAL)
	for enemy: Node in game.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.position.distance_to(source)<70:
			enemy.stun = 0.16 if enemy.kind in ["boss","tempest"] else 0.65
			enemy.mode = "recovery"
			enemy.timer = 0.32 if enemy.kind in ["boss","tempest"] else 0.65
			enemy.hurt(1.5,Vector2(signf(enemy.position.x-game.player.position.x)*220,-55))

func reset_encounter() -> void:
	combo = 0
	potions = 2
	if active_arena>=0:
		for enemy: Node in arena_members:
			if is_instance_valid(enemy):
				game.enemies.erase(enemy)
				enemy.queue_free()
		active_arena = -1
		arena_members.clear()
		wave = 0

func say(message: String) -> void:
	radio = message
	radio_time = 7
	game.radio_received.emit(message)

func ring(pos: Vector2, color: Color, radius: float) -> void:
	rings.append({"pos":pos,"color":color,"radius":radius,"life":0.55})

func path(file_name: String) -> String:
	if not storage_override.is_empty(): return storage_override.path_join(file_name)
	return game._record_path().get_base_dir().path_join(file_name)

func save_campaign() -> void:
	if game.state in ["menu","dead","victory"]: return
	if game.test_mode or restoring or not is_instance_valid(game.player) : return
	if game.boss_awake and not game.boss_defeated: return
	var data: Dictionary = {}
	for key: String in ["chapter","chapter_kills","total_kills","embers","relics","deaths","damage_bonus","pulse_bonus","bonus_health","elapsed","run_score","checkpoint","checkpoint_active","boss_defeated"]:
		data[key] = game.get(key)
	data.pos = game.safe_position
	data.health = maxi(1,game.player.health)
	data.energy = game.player.energy
	data.enemies = []
	for enemy: Node in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			data.enemies.append({"kind":enemy.kind,"pos":enemy.position,"health":enemy.health,"patrol":int(enemy.get_meta("patrol",-1))})
	data.pickups = game.pickups.duplicate(true)
	data.arenas = arenas.duplicate(true)
	data.chests = chests.duplicate(true)
	data.cleared = cleared
	data.focus = focus
	data.potions = potions
	data.secrets = secrets
	data.scenery = game.presentation.snapshot()
	data.world = game.campaign.snapshot()
	data.flame = game.flame.snapshot()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("campaign","version",4)
	cfg.set_value("campaign","data",data)
	DirAccess.make_dir_recursive_absolute(path(""))
	if cfg.save(path("journey.cfg"))==OK: saved_available = true

func finish_campaign() -> void:
	saved_available = false
	if not game.test_mode and FileAccess.file_exists(path("journey.cfg")):
		DirAccess.remove_absolute(path("journey.cfg"))

func resume_campaign() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path("journey.cfg"))!=OK: return
	var data: Dictionary = cfg.get_value("campaign","data",{})
	if data.is_empty(): return
	restoring = true
	game.chapter = int(data.chapter)
	game.bonus_health = mini(1,int(data.bonus_health))
	game._load_chapter()
	for key: String in ["chapter_kills","total_kills","embers","relics","deaths","damage_bonus","pulse_bonus","elapsed","run_score","checkpoint","checkpoint_active","boss_defeated"]:
		game.set(key,data[key])
	for enemy: Node in game.enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	game.enemies.clear()
	game.boss = null
	for saved: Dictionary in data.enemies:
		var enemy: Node = game._spawn_enemy(saved.kind,saved.pos)
		enemy.health = saved.health
		enemy.set_meta("patrol",int(saved.get("patrol",-1)))
		if saved.kind in ["boss","tempest"]: game.boss = enemy
	game.pickups.assign(data.pickups)
	arenas.assign(data.arenas)
	chests.assign(data.chests)
	cleared = int(data.cleared)
	focus = float(data.focus)
	potions = mini(2,int(data.potions))
	secrets = int(data.secrets)
	game.player.reset_at(data.pos)
	game.player.health = mini(game.player.max_health,int(data.health))
	game.player.energy = data.energy
	game.player.invulnerable = 1.5
	game.safe_position = data.pos
	game.presentation.restore(data.get("scenery",{}))
	game.campaign.restore(data.get("world",{}))
	game.flame.restore(data.get("flame",{}))
	game.damage_bonus = mini(2,game.damage_bonus)
	game.pulse_bonus = mini(2,game.pulse_bonus)
	game.camera.position.x = clampf(data.pos.x,320,game.level_width-320)
	restoring = false
	say("信号重新接通。灯塔一直在等你，信使。")

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,volume)))

func save_settings() -> void:
	apply_volume()
	if game.test_mode: return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("settings","volume",volume)
	cfg.set_value("settings","shake",shake_enabled)
	cfg.set_value("settings","difficulty",difficulty)
	DirAccess.make_dir_recursive_absolute(path(""))
	cfg.save(path("settings.cfg"))

func action(value: String) -> void:
	match value:
		"credits": game.state = "credits"
		"credits_back": game.state = "menu"
		"continue": resume_campaign()
		"settings":
			settings_return = game.state
			game.state = "settings"
		"settings_back": game.state = settings_return
		"volume":
			volume = fposmod(volume+0.2,1.19)
			save_settings()
		"shake":
			shake_enabled = not shake_enabled
			save_settings()
		"difficulty":
			difficulty = (difficulty+1)%3
			save_settings()
		"close": game.state = "playing"
		"buy_heal": buy(12,0)
		"buy_blade": buy(30+15*game.damage_bonus,1)
		"buy_pulse": buy(28+14*game.pulse_bonus,2)
		"quit":
			if game.state!="menu": save_campaign()
			if OS.has_feature("web"):
				var browser: Object = Engine.get_singleton("JavaScriptBridge")
				browser.eval("setTimeout(() => window.parent.location.reload(), 500)",true)
				return
			game.get_tree().quit()

func buy(price: int, item: int) -> void:
	if (item==1 and game.damage_bonus>=2) or (item==2 and game.pulse_bonus>=2):
		game.show_notice("该强化已达到上限，保留余烬用于修复补给")
		return
	if game.embers<price:
		game.show_notice("余烬不足，去探索高处的补给箱")
		return
	game.embers -= price
	match item:
		0:
			game.player.health = game.player.max_health
			potions = mini(2,potions+1)
		1: game.damage_bonus += 1
		2: game.pulse_bonus += 1
	game.audio.play_sfx("checkpoint")
	save_campaign()

func button(rect: Rect2,label: String,act: String,primary: bool=false) -> Dictionary:
	return {"rect":rect,"label":label,"action":act,"primary":primary}

func buttons() -> Array[Dictionary]:
	match game.state:
		"credits": return [button(Rect2(245,296,150,29),"返回标题","credits_back",true)]
		"settings":
			return [button(Rect2(206,130,228,31),"音量  %d%%  · 点击调整"%roundi(volume*100),"volume"),
				button(Rect2(206,172,228,31),"屏幕震动："+("开启" if shake_enabled else "关闭"),"shake"),
				button(Rect2(206,214,228,31),"难度："+["漫游","标准","挑战"][difficulty],"difficulty"),
				button(Rect2(245,268,150,31),"返回","settings_back",true)]
		"shop":
			return [button(Rect2(161,142,318,32),"12 余烬    完全治疗 + 一瓶修复剂","buy_heal"),
				button(Rect2(161,185,318,32),"刀锋 %d/2 · 伤害 +15%%  / %d 余烬"%[game.damage_bonus,30+15*game.damage_bonus],"buy_blade"),
				button(Rect2(161,228,318,32),"线圈 %d/2 · 射击 +12%%  / %d 余烬"%[game.pulse_bonus,28+14*game.pulse_bonus],"buy_pulse"),
				button(Rect2(245,282,150,28),"继续前进","close",true)]
		"journal": return [button(Rect2(245,292,150,29),"返回旅途   TAB","close",true)]
	return []

func _draw() -> void:
	if game.state=="menu" or not is_instance_valid(game.player): return
	for chest: Dictionary in chests:
		var p: Vector2 = chest.pos
		draw_rect(Rect2(p-Vector2(12,14),Vector2(24,14)),Color("223744"))
		draw_rect(Rect2(p-Vector2(13,18 if chest.open else 16),Vector2(26,5)),Color("8d7555"))
		for x: int in [-9,7]: draw_rect(Rect2(p+Vector2(x,-14),Vector2(3,13)),Color("b49b70"))
		draw_rect(Rect2(p-Vector2(2,11),Vector2(4,5)),Color("3f5456") if chest.open else AMBER)
		if not chest.open:
			draw_circle(p-Vector2(0,9),22,Color(1,0.7,0.3,0.035))
			if p.distance_to(game.player.position)<45:
				draw_string(FONT,p-Vector2(28,25),"E  补给箱",HORIZONTAL_ALIGNMENT_LEFT,-1,10,AMBER)
	if game.checkpoint_active and absf(game.player.position.x-game.checkpoint_x)<45 and active_arena<0:
		draw_string(FONT,Vector2(game.checkpoint_x-31,239),"E  修复工坊",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEAL)
	for ring_data: Dictionary in rings:
		var t: float = ring_data.life/0.55
		draw_arc(ring_data.pos,ring_data.radius*(1-t)+3,0,TAU,48,Color(ring_data.color,t),2+t*3)
		for i: int in range(9):
			var pt: Vector2 = ring_data.pos+Vector2.from_angle(i*TAU/9)*ring_data.radius*(1-t)
			draw_line(pt,pt+Vector2.from_angle(i*TAU/9)*10*t,Color(ring_data.color,t),2)
	if game.chapter==1:
		for x: float in [360.0,1555.0,2300.0]:
			var phase: float = fposmod(hazard_time+x*0.003,4.6)
			draw_rect(Rect2(x-14,295,28,5),Color("4e6264"))
			for j: int in range(5): draw_rect(Rect2(x-11+j*5,296,2,3),Color("122b32"))
			if phase>2.7 and not game.flame.lit.has(1):
				draw_rect(Rect2(x-15,292,30,2),AMBER)
			if phase>3.5 and not game.flame.lit.has(1):
				for j: int in range(12):
					var y: float = fposmod(j*7+weather_time*75,51)
					draw_rect(Rect2(x-10+sin(j+weather_time*10)*6,294-y,14,4),Color(0.7,0.9,0.83,0.35*(1-y/60)))

func draw_hud(h: Node2D) -> void:
	if game.state=="credits":
		h._overlay()
		h._panel(Rect2(99,24,442,312))
		h._center("为最后的光，致谢",63,23)
		h._center("EMBER RELAY / THE LONG ROAD 4.0",86,10,TEAL)
		h._center("美术 / 像素角色、环境、特效",122,11,AMBER)
		h._center("Luis Zuno / Ansimuz · Warped Caves",144,11)
		h._center("CC BY 3.0 · 已统一配色与改编",162,9,Color("a5b5ad"))
		h._center("城市 / 工业远景：Ansimuz · Warped City · CC0",182,10)
		h._center("工业图集：Robert / 0x72 · CC0",201,10)
		h._center("音乐：Pascal Belisle / Level 04 · Sci-fi Platformer 02",229,9,AMBER)
		h._center("感谢开放素材的创作者 · 来源与许可详见素材鸣谢文件",252,10)
		h._center("制作于 Godot Engine · 保留旧世界，点亮新旅途",274,9,TEAL)
		return
	if game.state in ["settings","shop","journal"]:
		h._overlay()
		h._panel(Rect2(126,42,388,285))
		if game.state=="settings":
			h._center("旅途设置",83,24)
			h._center("难度影响承受伤害；漫游适合轻松体验故事",109,10,Color("9aacaa"))
		elif game.state=="shop":
			h._center("中继站 · 修复工坊",82,22)
			h._center("可用余烬  %d"%game.embers,113,12,AMBER)
			if game.notice_timer>0: h._center(game.notice,278,9,TEAL)
		else:
			h._center("信使的旅途",80,23)
			h._center(game.chapter_names[game.chapter]+"  ·  "+game.chapter_codes[game.chapter],105,10,TEAL)
			for floor_rect: Rect2 in game.platforms:
				var x: float = 160+clampf(floor_rect.position.x/game.level_width,0,1)*320
				var y: float = 128+(floor_rect.position.y-170)*0.35
				var width: float = minf(480-x,floor_rect.size.x/game.level_width*320)
				h.draw_rect(Rect2(x,y,width,3),Color("63837e"))
			var px: float = 160+game.player.position.x/game.level_width*320
			h.draw_circle(Vector2(px,126+(game.player.position.y-170)*0.35),3,AMBER)
			h.draw_rect(Rect2(160+game.checkpoint_x/game.level_width*320,164,3,9),TEAL)
			h.draw_rect(Rect2(160+game.portal_x/game.level_width*320,160,5,13),AMBER)
			for chest: Dictionary in chests:
				if not chest.open:
					h.draw_rect(Rect2(160+chest.pos.x/game.level_width*320,123+(chest.pos.y-170)*0.35,4,4),Color("dcb47c"))
			h._center("● 你的位置     青色：中继站     方块：补给 / 出口",194,9,TEAL)
			h._center("记忆 %d / 18    补给箱 %d / 15    已击败 %d"%[game.relics,secrets,game.total_kills],213,12)
			var task: String = "击败"+game.campaign.BOSSES[game.chapter/3] if game.campaign.is_boss_sector() else "自由探索 %d / %d · 启动机关，抵达中继门"%[cleared,arenas.size()]
			h._center("当前任务："+task,241,10,AMBER)
			h._center("E 开箱 / 工坊    F 修复    Q 弹反    R 爆发",269,10,TEAL)
		return
	if game.state=="boss_intro":
		h.draw_rect(Rect2(0,0,640,48),Color("09131c"))
		h.draw_rect(Rect2(0,282,640,78),Color("09131c"))
		h._center("守护协议  /  最终防线",308,10,AMBER)
		h._center(game.campaign.BOSSES[game.chapter/3],339,25)
		return
	if game.state!="playing": return
	if combo>=2:
		h._text("%02d"%combo,Vector2(19,111),24,AMBER)
		h._text("连击 / "+("S" if combo>=20 else "A" if combo>=10 else "B"),Vector2(56,107),10,TEAL)
	if active_arena>=0:
		h._center("巡逻区域  %d  /  第 %d 波"%[active_arena+1,maxi(1,wave)],68,10,RED)
	if radio_time>0 and game.presentation.sector_title<=0 and game.notice_timer<=0 and active_arena<0 and not game.boss_awake:
		h.draw_rect(Rect2(157,281,326,46),Color(0.04,0.12,0.17,0.94))
		h.draw_rect(Rect2(157,281,2,46),TEAL)
		h._text("灯塔  /  通讯接入",Vector2(167,294),9,TEAL)
		var line1: String = radio.substr(0,29)
		var line2: String = radio.substr(29)
		h._text(line1,Vector2(167,308),10)
		h._text(line2,Vector2(167,321),10)
