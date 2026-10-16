extends Node2D

const CampaignScript = preload("res://scripts/campaign.gd")
const StormScript = preload("res://scripts/storm_boss.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BackdropScript = preload("res://scripts/backdrop.gd")
const HudScript = preload("res://scripts/hud.gd")
const DirectorScript = preload("res://scripts/director.gd")
const SceneryScript = preload("res://scripts/scenery.gd")
const PresentationScript = preload("res://scripts/presentation.gd")
const AudioScript = preload("res://scripts/audio.gd")
const FONT = preload("res://assets/ui_font.ttc")
const AMBER = Color("f4ad68")
const TEAL = Color("79d8cc")
const CREAM = Color("eee5cd")

var campaign: Node2D
var director: Node2D
var scenery: Node2D
var presentation: Node2D
var menu_ui: Control
var hit_pause: float = 0.0
var ui_focus: int = 0
signal screen_changed
signal menu_changed
var state: String = "menu":
	set(value):
		if state==value: return
		state = value
		screen_changed.emit()
var chapter: int = 0
var chapter_names: Array[String] = ["风蚀前哨", "雨蚀管廊", "最后的熔炉", "潮汐船坞", "断弦高架", "风暴之眼"]
var chapter_codes: Array[String] = ["THE ASHEN OUTPOST", "THE RAINWORN CONDUIT", "THE LAST FURNACE", "THE TIDAL DOCKS", "THE BROKEN SKYRAIL", "THE STORM ENGINE"]
var world: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: Node2D
var audio: Node
var backdrop: Node2D
var platforms: Array[Rect2] = []
var enemies: Array[Node] = []
var pickups: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var lamps: Array[Vector2] = []
var chapter_kills: int = 0
var total_kills: int = 0
var kill_goal: int = 5
var embers: int = 0
var relics: int = 0
var deaths: int = 0
var damage_bonus: int = 0
var pulse_bonus: int = 0
var bonus_health: int = 0
var elapsed: float = 0.0
var clock: float = 0.0
var level_width: float = 2350.0
var world_bottom: float = 430.0
var checkpoint: Vector2 = Vector2(75, 296)
var checkpoint_active: bool = false
var checkpoint_x: float = 1080
var safe_position: Vector2 = Vector2(75, 290)
var portal_x: float = 2240
var boss: Node
var boss_awake: bool = false
var boss_defeated: bool = false
var shake: float = 0.0
var damage_flash: float = 0.0
var banner_timer: float = 0.0
var notice: String = ""
var notice_timer: float = 0.0
var menu_help: bool = false:
	set(value):
		if menu_help==value: return
		menu_help = value
		menu_changed.emit()
var muted: bool = false
var best_score: int = 0
var best_time: float = 0.0
var run_score: int = 0
var transition_alpha: float = 0.0
var test_mode: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_setup_input()
	_load_record()
	audio = AudioScript.new()
	add_child(audio)
	var sky_layer: CanvasLayer = CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	backdrop = BackdropScript.new()
	backdrop.game = self
	sky_layer.add_child(backdrop)
	world = Node2D.new()
	add_child(world)
	camera = Camera2D.new()
	camera.position = Vector2(320, 180)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	var ui_layer: CanvasLayer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = HudScript.new()
	hud.game = self
	ui_layer.add_child(hud)
	campaign = CampaignScript.new()
	campaign.game = self
	add_child(campaign)
	campaign.reset()
	director = DirectorScript.new()
	director.game = self
	add_child(director)
	scenery = SceneryScript.new()
	scenery.game = self
	scenery.z_index = -1
	add_child(scenery)
	presentation = PresentationScript.new()
	presentation.game = self
	add_child(presentation)
	menu_ui = preload("res://scripts/menu_ui.gd").new()
	menu_ui.game = self
	ui_layer.add_child(menu_ui)
	_build_menu_scene()
	if "--smoke-test" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("_smoke_test")
	if "--capture-menu" in OS.get_cmdline_user_args():
		call_deferred("_capture", "menu")
	if "--capture-play" in OS.get_cmdline_user_args():
		test_mode = true
		start_game()
		campaign.action("depart")
		call_deferred("_capture", "gameplay")

func _setup_input() -> void:
	var keys: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J],
		"pulse": [KEY_K], "dash": [KEY_SHIFT, KEY_L],
		"parry": [KEY_Q], "heal": [KEY_F], "burst": [KEY_R], "down": [KEY_S, KEY_DOWN], "journal": [KEY_TAB],
		"interact": [KEY_E], "pause_game": [KEY_ESCAPE], "retry": [KEY_R], "mute": [KEY_M]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in keys[action]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var left: InputEventMouseButton = InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", left)
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("pulse", right)

func _build_menu_scene() -> void:
	platforms = [Rect2(-30, 300, 720, 90), Rect2(363, 275, 192, 25)]
	lamps = [Vector2(356, 273), Vector2(570, 300)]
	portal_x = 468
	queue_redraw()

func start_game() -> void:
	_clear_world()
	campaign.reset()
	director.potions = 2
	director.focus = 0
	director.secrets = 0
	director.tips_seen.clear()
	chapter = 0
	total_kills = 0
	embers = 0
	relics = 0
	deaths = 0
	damage_bonus = 0
	pulse_bonus = 0
	bonus_health = 0
	elapsed = 0
	run_score = 0
	menu_help = false
	state = "world_map"
	campaign.map_return = "menu"
	ui_focus = 0

func _clear_world() -> void:
	for child: Node in world.get_children():
		world.remove_child(child)
		child.queue_free()
	enemies.clear()
	platforms.clear()
	pickups.clear()
	projectiles.clear()
	particles.clear()
	texts.clear()
	lamps.clear()
	boss = null
	player = null

func _load_chapter() -> void:
	_clear_world()
	chapter_kills = 0
	checkpoint_active = false
	boss_awake = false
	boss_defeated = false
	checkpoint = Vector2(75, 294)
	safe_position = checkpoint
	checkpoint_x = 1080
	level_width = 2350 if chapter != 1 else 2580
	portal_x = level_width - 110
	kill_goal = [5, 6, 1, 8, 8, 1][chapter]
	if chapter == 0:
		platforms = [Rect2(-60,300,740,160), Rect2(770,300,675,160), Rect2(1530,300,880,160),
			Rect2(258,246,106,14), Rect2(435,204,112,14), Rect2(865,241,125,14),
			Rect2(1185,223,110,14), Rect2(1370,193,100,14), Rect2(1660,248,108,14), Rect2(1870,214,140,14)]
		lamps = [Vector2(190,300), Vector2(820,300), Vector2(1305,300), Vector2(1770,300), Vector2(2170,300)]
	elif chapter == 1:
		platforms = [Rect2(-60,300,600,160), Rect2(625,300,760,160), Rect2(1480,300,480,160), Rect2(2045,300,600,160),
			Rect2(240,239,110,14), Rect2(420,196,100,14), Rect2(720,248,125,14), Rect2(950,208,130,14),
			Rect2(1190,247,105,14), Rect2(1350,204,170,14), Rect2(1710,235,125,14), Rect2(1940,202,150,14), Rect2(2220,244,110,14)]
		lamps = [Vector2(170,300), Vector2(680,300), Vector2(1145,300), Vector2(1650,300), Vector2(2140,300)]
	else:
		platforms = [Rect2(-60,300,1030,160), Rect2(1050,300,1360,160), Rect2(260,245,140,14), Rect2(520,204,130,14), Rect2(825,239,145,14), Rect2(1210,248,120,14)]
		lamps = [Vector2(190,300), Vector2(710,300), Vector2(1150,300), Vector2(1540,300), Vector2(2120,300)]
	if chapter>=3:
		var layout: Dictionary = campaign.extra_layout(chapter)
		platforms.assign(layout.platforms)
		lamps.assign(layout.lamps)
		level_width = layout.width
		portal_x = level_width-110
		checkpoint_x = campaign.checkpoints()[0]
	for rect: Rect2 in platforms:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		shape.one_way_collision = rect.size.y < 30
		shape.one_way_collision_margin = 3.0
		body.add_child(shape)
		world.add_child(body)
	# Invisible side walls keep the little adventure inside its authored space.
	for x: float in [-50.0, level_width + 50.0]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.collision_layer = 1
		var collider: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = Vector2(100,800)
		collider.shape = box
		collider.position = Vector2(x,100)
		wall.add_child(collider)
		world.add_child(wall)
	player = PlayerScript.new()
	player.game = self
	player.max_health = 6 + mini(1,bonus_health) + (2 if director.difficulty==0 else 0)
	world.add_child(player)
	player.reset_at(checkpoint)
	if chapter>=3:
		var layout: Dictionary = campaign.extra_layout(chapter)
		for foe: Array in layout.enemies: _spawn_enemy(foe[0],Vector2(foe[1],foe[2]))
		if chapter==5: boss = _spawn_enemy("tempest",campaign.boss_home())
	elif chapter == 0:
		_spawn_enemy("scout", Vector2(480,290))
		_spawn_enemy("drone", Vector2(1420,170))
	elif chapter == 1:
		_spawn_enemy("guard", Vector2(415,290))
		_spawn_enemy("drone", Vector2(2250,190))
	else:
		_spawn_enemy("guard", Vector2(430,290))
		_spawn_enemy("drone", Vector2(850,190))
		boss = _spawn_enemy("boss", Vector2(1850,290))
	for rect: Rect2 in platforms:
		if rect.size.y < 30:
			for i: int in range(3):
				_add_pickup(rect.position + Vector2(22 + i * 25, -18), "ember")
	var relic_positions: Array[Vector2]
	if chapter>=3:
		relic_positions.assign(campaign.extra_layout(chapter).relics)
	elif chapter == 0:
		relic_positions = [Vector2(490,173),Vector2(1420,162),Vector2(1940,183)]
	elif chapter == 1:
		relic_positions = [Vector2(470,165),Vector2(1420,173),Vector2(2010,171)]
	else:
		relic_positions = [Vector2(590,173),Vector2(900,208),Vector2(1275,217)]
	for pos: Vector2 in relic_positions:
		_add_pickup(pos,"relic")
	_add_pickup(Vector2(1320 if chapter != 2 else 1190,276),"heal")
	director.configure()
	presentation.configure()
	campaign.sector_loaded()
	state = "playing"
	banner_timer = 3.5
	transition_alpha = 1
	camera.position = Vector2(320,180)
	camera.offset = Vector2.ZERO
	audio.set_intensity(0.25 + chapter * 0.2)
	audio.set_region(chapter/3)
	queue_redraw()

func _spawn_enemy(kind: String, pos: Vector2) -> Node:
	var enemy: Node = StormScript.new() if kind=="tempest" else EnemyScript.new()
	enemy.setup(kind, pos, self)
	world.add_child(enemy)
	enemies.append(enemy)
	return enemy

func _add_pickup(pos: Vector2, kind: String) -> void:
	pickups.append({"pos":pos,"kind":kind,"phase":randf()*TAU})

func _process(delta: float) -> void:
	clock += delta
	hit_pause = maxf(0,hit_pause-delta)
	transition_alpha = move_toward(transition_alpha,0,delta*2)
	damage_flash = move_toward(damage_flash,0,delta*2)
	notice_timer = maxf(0, notice_timer-delta)
	if state == "playing":
		elapsed += delta
		banner_timer = maxf(0,banner_timer-delta)
		var target_x: float = clampf(player.position.x + player.facing * 38.0,320,level_width-320)
		if boss_awake and not boss_defeated:
			target_x = clampf(target_x,campaign.arena_start()+250,level_width-320)
		camera.position.x = lerpf(camera.position.x,target_x,1-exp(-delta*6))
		shake = move_toward(shake,0,delta*18)
		camera.offset = (Vector2(sin(clock*73),sin(clock*91))*shake).round() if director.shake_enabled else Vector2.ZERO
		_update_particles(delta)
		for i: int in range(texts.size()-1,-1,-1):
			texts[i].life -= delta
			texts[i].pos.y -= delta*19
			if texts[i].life <= 0:
				texts.remove_at(i)
	queue_redraw()
	hud.queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "playing" or not is_instance_valid(player):
		return
	if hit_pause>0: return
	director.tick(delta)
	presentation.tick(delta)
	if state!="playing": return
	_update_projectiles(delta)
	_update_pickups()
	if player.position.y > world_bottom:
		player.invulnerable = 0
		player.hurt(2,player.position+Vector2(0,40),0)
		if state == "playing":
			player.position = safe_position
			player.velocity = Vector2.ZERO
			player.invulnerable = 1.5
			show_notice("坠落损失 2 格生命。继续前进。")
	if player.is_on_floor() and player.position.y < 310:
		for floor_rect: Rect2 in platforms:
			if absf(player.position.y-floor_rect.position.y)<4 and player.position.x>floor_rect.position.x+13 and player.position.x<floor_rect.end.x-13:
				safe_position = player.position + Vector2(0,-4)
				break
	for rest_x: float in campaign.checkpoints():
		if not campaign.rest_points.has(rest_x) and absf(player.position.x-rest_x)<28 and player.position.y>250:
			campaign.rest_points.append(rest_x)
			checkpoint_active = true
			checkpoint_x = rest_x
			director.potions = 2
			checkpoint = Vector2(checkpoint_x,294)
			player.health = player.max_health
			player.energy = 100
			audio.play_sfx("checkpoint")
			fx_burst(checkpoint+Vector2(0,-20),TEAL,30)
			show_notice("中继站已点亮 · 恢复生命与修复剂 · 旅途已保存")
			director.save_campaign()
	if campaign.is_boss_sector() and not boss_awake and not boss_defeated and player.position.x>campaign.arena_start()+15:
		boss_awake = true
		state = "boss_intro"
		director.boss_intro = 2.2
		audio.play_sfx("boss")
		audio.set_intensity(1)
		show_notice("风暴织机已锁定信号 · 看清落雷预警，抓住俯冲后的反击窗口" if chapter==5 else "熔炉看守已苏醒 · 警惕连续震地，抓住锤击后的反击窗口")
	if boss_awake and not boss_defeated and player.position.x < campaign.arena_start():
		player.position.x = campaign.arena_start()
	if Input.is_action_just_pressed("interact") and player.position.x<55 and chapter%3>0:
		campaign.travel_to(chapter-1,false)
		return
	if Input.is_action_just_pressed("interact") and absf(player.position.x-portal_x)<62:
		if gate_open():
			if chapter==5:
				if not campaign.completed.has(1): campaign.completed.append(1)
				_complete_run()
			elif chapter==2:
				state = "upgrade"
			else:
				campaign.travel_to(chapter+1)
				audio.play_sfx("checkpoint")
		else:
			show_notice("先启动本区机关，再解除封锁 %d / %d" % [director.cleared,director.arenas.size()])

func gate_open() -> bool:
	return boss_defeated if campaign.is_boss_sector() else director.cleared>=director.arenas.size() and (chapter<3 or presentation.circuit_on)


func player_melee(area: Rect2, damage: int, knock: Vector2, combo: int) -> void:
	presentation.strike(area,damage*(1+0.15*mini(2,damage_bonus)))
	var hit: bool = false
	for enemy: Node in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var size: Vector2 = Vector2(34,54) if enemy.kind in ["boss","tempest"] else Vector2(24,30)
		var enemy_rect: Rect2 = Rect2(enemy.position-Vector2(size.x*0.5,size.y),size)
		if area.intersects(enemy_rect):
			enemy.hurt(damage*(1+0.15*mini(2,damage_bonus)),knock)
			director.hit()
			presentation.impact(enemy.position-Vector2(0,18),combo==3)
			floating_number(enemy.position+Vector2(0,-38),str(damage*(1+0.15*mini(2,damage_bonus))),AMBER)
			hit = true
	if hit:
		add_shake(2.5 if combo<3 else 4.0)
		player.energy = minf(100,player.energy+2)

func spawn_projectile(origin: Vector2, velocity: Vector2, damage: int, hostile: bool, color: Color) -> void:
	projectiles.append({"pos":origin,"prev":origin,"vel":velocity,"damage":damage if hostile else damage*(1+0.12*mini(2,pulse_bonus)),"hostile":hostile,"color":color,"life":3.5})

func _update_projectiles(delta: float) -> void:
	for i: int in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		p.prev = p.pos
		p.pos += p.vel * delta
		p.life -= delta
		var remove: bool = p.life<=0
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(p.prev,p.pos,1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			remove = true
		if not remove and p.hostile:
			if Rect2(player.position-Vector2(10,29),Vector2(20,29)).grow(3).has_point(p.pos):
				if player.parry_time>0:
					director.parry(p.pos)
					p.hostile = false
					p.vel *= -1.8
					p.damage = 3
					p.color = TEAL
					p.pos += p.vel.normalized()*18
					player.parry_time = 0
				else:
					player.hurt(p.damage,p.pos,100)
					# Death clears the projectile array while this update is running.
					if state!="playing": return
					remove = true
		elif not remove:
			for enemy: Node in enemies.duplicate():
				if not is_instance_valid(enemy) or enemy.dead:
					continue
				var size: Vector2 = Vector2(40,56) if enemy.kind in ["boss","tempest"] else Vector2(28,32)
				if Rect2(enemy.position-Vector2(size.x*0.5,size.y),size).grow(4).has_point(p.pos):
					enemy.hurt(p.damage,Vector2(signf(p.vel.x)*170,-60))
					director.hit()
					presentation.impact(p.pos,false)
					floating_number(enemy.position+Vector2(0,-38),str(p.damage),TEAL)
					remove = true
					break
		# Defeating a boss clears every projectile, including the current one.
		if projectiles.is_empty(): return
		if remove:
			fx_burst(p.pos,p.color,5)
			projectiles.remove_at(i)

func _update_pickups() -> void:
	for i: int in range(pickups.size()-1,-1,-1):
		var p: Dictionary = pickups[i]
		var distance: float = player.position.distance_to(p.pos+Vector2(0,14))
		if distance<80 and p.kind=="ember":
			p.pos = p.pos.move_toward(player.position-Vector2(0,14),4)
		if distance < 26:
			match p.kind:
				"ember":
					embers += 1
					run_score += 20
					player.energy = minf(100,player.energy+3)
				"relic":
					relics += 1
					run_score += 200
					floating_number(p.pos,"记忆 +1",TEAL)
					show_notice("发现旧世界的记忆 · 已收集 %d / 18" % relics)
				"heal":
					player.health = mini(player.max_health,player.health+1)
					floating_number(p.pos,"生命 +1",TEAL)
			audio.play_sfx("pickup")
			fx_burst(p.pos,TEAL if p.kind!="ember" else AMBER,9)
			pickups.remove_at(i)

func on_enemy_killed(enemy: Node) -> void:
	chapter_kills += 1
	total_kills += 1
	run_score += 150 if enemy.kind=="guard" else 100
	if enemy.kind in ["boss","tempest"]:
		boss_defeated = true
		presentation.finale = 2.0
		director.ring(enemy.position-Vector2(0,36),AMBER,220)
		run_score += 1500
		projectiles.clear()
		show_notice("风暴已经散去，前往终点传递火种。" if chapter==5 else "熔炉已经沉寂，前往中继门接通苍穹航线。")
		director.save_campaign()
		audio.play_sfx("win")
		fx_burst(enemy.position+Vector2(0,-28),AMBER,65)
		add_shake(9)
	else:
		for offset: int in [-9,0,9]:
			_add_pickup(enemy.position+Vector2(offset,-14),"ember")
		if chapter_kills%5==0:
			_add_pickup(enemy.position+Vector2(14,-15),"heal")
		audio.play_sfx("kill")
	enemies.erase(enemy)
	if not campaign.is_boss_sector() and chapter_kills==kill_goal:
		show_notice("区域已净化 · 前往右侧中继门，按 E 进入下一区域")
		audio.play_sfx("checkpoint")

func on_player_hurt() -> void:
	damage_flash = 0.32
	add_shake(4)

func on_player_died() -> void:
	state = "dead"
	deaths += 1
	camera.offset = Vector2.ZERO

func respawn() -> void:
	projectiles.clear()
	director.reset_encounter()
	boss_awake = false
	if is_instance_valid(boss) and not boss.dead:
		boss.health = boss.max_health
		boss.position = campaign.boss_home()
		boss.velocity = Vector2.ZERO
		boss.phase = 1
		boss.mode = "idle"
		boss.cooldown = 1.6
		boss.timer = 0.6
		boss.stun = 0
		boss.knock_velocity = 0
		boss.attack_index = 0
		boss.phase_pulse = 0
		boss.attack_kind = ""
		boss.attack_hit = false
		if boss.kind=="tempest":
			boss.lightning.clear()
			boss.shots_left = 0
	player.reset_at(checkpoint)
	player.invulnerable = 2
	safe_position = checkpoint
	state = "playing"
	show_notice("火种尚未熄灭。再试一次。")

func choose_upgrade(which: int) -> void:
	audio.play_sfx("click")
	campaign.finish_region(which)

func _complete_run() -> void:
	if state=="victory": return
	state = "victory"
	director.finish_campaign()
	run_score += maxi(0,1500-int(elapsed)*2) + relics*100
	best_score = maxi(best_score,run_score)
	if best_time==0 or elapsed<best_time:
		best_time = elapsed
	_save_record()
	audio.play_sfx("win")
	audio.set_intensity(0.2)

func return_to_menu() -> void:
	director.save_campaign()
	_clear_world()
	state = "menu"
	chapter = 0
	camera.position = Vector2(320,180)
	camera.offset = Vector2.ZERO
	menu_help = false
	audio.set_intensity(0.15)
	audio.set_region(0)
	_build_menu_scene()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state=="world_map":
			if event.physical_keycode in [KEY_LEFT,KEY_1,KEY_UP]: campaign.selected = 0; return
			if event.physical_keycode in [KEY_RIGHT,KEY_2,KEY_DOWN]: campaign.selected = 1; return
			if event.physical_keycode==KEY_ENTER: activate_button("depart"); return
		var ui_buttons: Array[Dictionary] = get_buttons()
		if state!="playing" and state!="boss_intro" and state!="menu" and not ui_buttons.is_empty():
			if event.physical_keycode in [KEY_UP,KEY_W,KEY_DOWN,KEY_S]:
				ui_focus = posmod(ui_focus+(-1 if event.physical_keycode in [KEY_UP,KEY_W] else 1),ui_buttons.size())
				audio.play_sfx("click")
				return
			if event.physical_keycode==KEY_ENTER:
				activate_button(ui_buttons[mini(ui_focus,ui_buttons.size()-1)].action)
				ui_focus = 0
				return
		if event.physical_keycode==KEY_F11:
			var full: bool = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event.is_action_pressed("mute"):
			muted = not muted
			audio.set_muted(muted)
		if event.is_action_pressed("pause_game"):
			if state=="playing":
				state = "paused"
			elif state=="paused":
				state = "playing"
			elif state=="menu":
				menu_help = false
		if state=="boss_intro" and event.physical_keycode==KEY_ENTER:
			director.boss_intro = 0
		if event.is_action_pressed("journal"):
			if state=="playing": campaign.open_map()
			elif state in ["journal","world_map"]: state = "playing" if is_instance_valid(player) else "menu"
		if event.is_action_pressed("pause_game") and state in ["shop","journal","settings","credits","world_map"]:
			state = campaign.map_return if state=="world_map" else "world_map" if state=="journal" else "menu" if state=="credits" else director.settings_return if state=="settings" else "playing"
			return
		if event.physical_keycode==KEY_ENTER:
			if state=="menu": return
			elif state=="dead": respawn()
			elif state=="victory": start_game()
		if event.is_action_pressed("retry") and state=="dead": respawn()
		if state=="upgrade":
			if event.physical_keycode==KEY_1: choose_upgrade(0)
			elif event.physical_keycode==KEY_2: choose_upgrade(1)
			elif event.physical_keycode==KEY_3: choose_upgrade(2)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if state=="menu": return
		var mouse: Vector2 = hud.get_local_mouse_position()
		for button: Dictionary in get_buttons():
			if button.rect.has_point(mouse):
				activate_button(button.action)
				get_viewport().set_input_as_handled()
				break

func activate_button(action: String) -> void:
	audio.play_sfx("click")
	campaign.action(action)
	director.action(action)
	match action:
		"start": start_game()
		"help": menu_help = not menu_help
		"resume": state = "playing"
		"respawn": respawn()
		"menu": return_to_menu()
		"mute":
			muted = not muted
			audio.set_muted(muted)
		"upgrade0": choose_upgrade(0)
		"upgrade1": choose_upgrade(1)
		"upgrade2": choose_upgrade(2)

func get_buttons() -> Array[Dictionary]:
	var routes: Array[Dictionary] = campaign.buttons()
	if not routes.is_empty(): return routes
	var extra: Array[Dictionary] = director.buttons()
	if not extra.is_empty(): return extra
	match state:
		"menu":
			if menu_help:
				return [{"rect":Rect2(235,291,170,32),"label":"明白了 · 返回","action":"help","primary":true}]
			var list: Array[Dictionary] = [director.button(Rect2(38,222,206,32),"继续旅程    →" if director.saved_available else "航线总览    →","continue" if director.saved_available else "start",true),
				director.button(Rect2(38,261,98,25),"信使手册","help"), director.button(Rect2(146,261,98,25),"旅途设置","settings"),
				director.button(Rect2(553,321,60,22),"离开","quit")]
			if director.saved_available: list.append(director.button(Rect2(38,294,206,22),"重新点燃 · 新旅程","start"))
			return list
		"paused":
			return [{"rect":Rect2(225,194,190,34),"label":"继续旅程    ESC","action":"resume","primary":true},
				{"rect":Rect2(225,236,190,24),"label":"旅途设置","action":"settings","primary":false},
				{"rect":Rect2(225,266,190,24),"label":"返回主菜单","action":"menu","primary":false}]
		"dead":
			return [{"rect":Rect2(208,211,224,35),"label":"从中继站重试    R","action":"respawn","primary":true},
				{"rect":Rect2(250,258,140,28),"label":"返回主菜单","action":"menu","primary":false}]
		"victory":
			return [{"rect":Rect2(170,283,145,33),"label":"再送一次火种","action":"start","primary":true},
				{"rect":Rect2(325,283,145,33),"label":"返回主菜单","action":"menu","primary":false}]
		"upgrade":
			return [{"rect":Rect2(45,126,174,168),"label":"","action":"upgrade0","primary":false},
				{"rect":Rect2(233,126,174,168),"label":"","action":"upgrade1","primary":false},
				{"rect":Rect2(421,126,174,168),"label":"","action":"upgrade2","primary":false}]
	return []

func fx_burst(pos: Vector2, color: Color, count: int) -> void:
	for i: int in range(mini(count,260-particles.size())):
		var angle: float = randf()*TAU
		var speed: float = randf_range(20,115)
		particles.append({"pos":pos,"vel":Vector2.from_angle(angle)*speed,"life":randf_range(0.22,0.65),"color":color,"size":2 if i%3==0 else 1})

func _update_particles(delta: float) -> void:
	for i: int in range(particles.size()-1,-1,-1):
		particles[i].pos += particles[i].vel*delta
		particles[i].vel.y += 180*delta
		particles[i].life -= delta
		if particles[i].life<=0:
			particles.remove_at(i)

func floating_number(pos: Vector2, value: String, color: Color) -> void:
	texts.append({"pos":pos,"value":value,"color":color,"life":0.8})

func add_shake(amount: float) -> void:
	shake = maxf(shake,amount)

func show_notice(value: String) -> void:
	notice = value
	notice_timer = 4

func _load_record() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(_record_path())==OK:
		best_score = int(cfg.get_value("record","score",0))
		best_time = float(cfg.get_value("record","time",0.0))

func _save_record() -> void:
	if test_mode: return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("record","score",best_score)
	cfg.set_value("record","time",best_time)
	var save_path: String = _record_path()
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	if cfg.save(save_path)!=OK:
		push_warning("Could not save the local high score: "+save_path)

func _record_path() -> String:
	if OS.has_feature("web"): return "user://save/record.cfg"
	# Scores travel with the project or the portable game folder.
	var base_path: String = ProjectSettings.globalize_path("res://")
	if base_path.is_empty():
		base_path = OS.get_executable_path().get_base_dir()
	return base_path.path_join("save/record.cfg")

func format_time(value: float) -> String:
	return "%02d:%02d" % [int(value)/60,int(value)%60]

func _draw() -> void:
	if state=="menu": return
	_draw_terrain()
	_draw_props()
	for p: Dictionary in pickups:
		var pos: Vector2 = p.pos + Vector2(0,sin(clock*3+p.phase)*3)
		if p.kind=="ember":
			draw_circle(pos,7,Color(0.96,0.58,0.28,0.08))
			draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-4),pos+Vector2(3,0),pos+Vector2(0,4),pos+Vector2(-3,0)]),AMBER)
			draw_rect(Rect2(pos-Vector2(1,2),Vector2(1,3)),CREAM)
		elif p.kind=="relic":
			draw_circle(pos,11,Color(0.4,0.9,0.85,0.08))
			draw_arc(pos,9,clock,clock+4.8,16,TEAL,1)
			draw_rect(Rect2(pos-Vector2(4,6),Vector2(8,12)),Color("2e6c71"))
			draw_rect(Rect2(pos-Vector2(2,4),Vector2(4,8)),TEAL)
			draw_rect(Rect2(pos-Vector2(1,3),Vector2(2,3)),CREAM)
		else:
			draw_rect(Rect2(pos-Vector2(6,6),Vector2(12,12)),Color("203d40"))
			draw_rect(Rect2(pos-Vector2(2,4),Vector2(4,8)),TEAL)
			draw_rect(Rect2(pos-Vector2(4,2),Vector2(8,4)),TEAL)
	for p: Dictionary in projectiles:
		var direction: Vector2 = p.vel.normalized()
		draw_line(p.pos-direction*12,p.pos,p.color,3)
		draw_circle(p.pos,3,CREAM if not p.hostile else Color("ffe0bd"))
	for p: Dictionary in particles:
		var col: Color = p.color
		col.a = minf(1,p.life*4)
		draw_rect(Rect2(p.pos,Vector2.ONE*p.size),col)
	for item: Dictionary in texts:
		var col: Color = item.color
		col.a = minf(1,item.life*3)
		draw_string(FONT,item.pos+Vector2(-6,0),item.value,HORIZONTAL_ALIGNMENT_LEFT,-1,10,col)

func _draw_terrain() -> void:
	preload("res://scripts/art.gd").terrain(self,platforms,camera.position.x,chapter)

func _draw_props() -> void:
	for lamp: Vector2 in lamps:
		if absf(lamp.x-camera.position.x)>360: continue
		draw_rect(Rect2(lamp+Vector2(-2,-58),Vector2(4,58)),Color("1a2630"))
		draw_rect(Rect2(lamp+Vector2(-3,-60),Vector2(19,3)),Color("55636a"))
		draw_line(lamp+Vector2(13,-58),lamp+Vector2(13,-49),Color("38464d"),1)
		var light: Vector2 = lamp+Vector2(13,-45)
		draw_circle(light,16,Color(0.96,0.65,0.36,0.035))
		draw_circle(light,9,Color(0.96,0.65,0.36,0.06))
		draw_rect(Rect2(light-Vector2(4,5),Vector2(8,10)),Color("7e684e"))
		draw_rect(Rect2(light-Vector2(2,3),Vector2(4,6)),Color("f3c483"))
	if state != "menu":
		_draw_beacon(Vector2(checkpoint_x,300),checkpoint_active)
		if chapter%3>0:
			draw_rect(Rect2(12,241,14,59),Color("3c565d"))
			draw_rect(Rect2(16,245,6,49),TEAL)
			draw_string(FONT,Vector2(28,253),"← 上一区域",HORIZONTAL_ALIGNMENT_LEFT,-1,9,TEAL)
			if is_instance_valid(player) and player.position.x<65:
				draw_string(FONT,Vector2(29,272),"E 返回",HORIZONTAL_ALIGNMENT_LEFT,-1,10,CREAM)
		# Environmental story: direction markers and abandoned containers.
		for i: int in range(5):
			var x: float = 215+i*420
			if absf(x-camera.position.x)>380: continue
			draw_rect(Rect2(x+39,263,2,37),Color("405258"))
			draw_rect(Rect2(x+29,259,25,13),Color("24343c"))
			draw_string(FONT,Vector2(x+33,270),"→",HORIZONTAL_ALIGNMENT_LEFT,-1,12,AMBER)
		if chapter==2:
			_draw_furnace()
			if boss_awake and not boss_defeated:
				for y: int in range(130,300,9):
					draw_rect(Rect2(1484,y,4,6),Color(0.94,0.41,0.32,0.6+sin(clock*4)*0.2))
	_draw_portal(Vector2(portal_x,300 if state!="menu" else 275),gate_open() if state!="menu" else true)

func _draw_beacon(pos: Vector2, active: bool) -> void:
	var color: Color = TEAL if active else Color("849892")
	draw_rect(Rect2(pos+Vector2(-12,-4),Vector2(24,4)),Color("4e5e5e"))
	draw_rect(Rect2(pos+Vector2(-6,-35),Vector2(12,32)),Color("2b4148"))
	draw_rect(Rect2(pos+Vector2(-3,-31),Vector2(6,18)),color)
	draw_rect(Rect2(pos+Vector2(-9,-40),Vector2(18,5)),Color("6a7973"))
	draw_circle(pos+Vector2(0,-28),20,Color(color.r,color.g,color.b,0.06))
	draw_string(FONT,pos+Vector2(-17,-47),"中继站",HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)

func _draw_portal(pos: Vector2, active: bool) -> void:
	var color: Color = TEAL if active else Color("a17c64")
	draw_rect(Rect2(pos+Vector2(-35,-6),Vector2(70,6)),Color("596563"))
	draw_rect(Rect2(pos+Vector2(-29,-87),Vector2(12,81)),Color("283840"))
	draw_rect(Rect2(pos+Vector2(17,-87),Vector2(12,81)),Color("283840"))
	draw_rect(Rect2(pos+Vector2(-35,-96),Vector2(70,12)),Color("39494e"))
	draw_rect(Rect2(pos+Vector2(-33,-96),Vector2(66,3)),Color("74827b"))
	draw_rect(Rect2(pos+Vector2(-22,-79),Vector2(3,70)),color)
	draw_rect(Rect2(pos+Vector2(19,-79),Vector2(3,70)),color)
	for y: int in range(0,4):
		draw_rect(Rect2(pos+Vector2(-28,-75+y*17),Vector2(4,4)),Color("8b9380"))
		draw_rect(Rect2(pos+Vector2(24,-75+y*17),Vector2(4,4)),Color("8b9380"))
	if active:
		draw_rect(Rect2(pos+Vector2(-18,-83),Vector2(36,77)),Color(0.35,0.85,0.77,0.09))
		for i: int in range(14):
			var y: float = fposmod(i*7.0-clock*13,75)
			draw_rect(Rect2(pos+Vector2(-17,-82+y),Vector2(34,1)),Color(0.44,0.86,0.8,0.09+sin(i+clock)*0.04))
		for i: int in range(7):
			var y: float = fposmod(i*13.0-clock*19,73)
			var x: float = sin(i*4.0+clock)*12
			draw_rect(Rect2(pos+Vector2(x,-9-y),Vector2(2,2)),color)
	draw_string(FONT,pos+Vector2(-19,-103),"RELAY",HORIZONTAL_ALIGNMENT_LEFT,-1,10,CREAM)
	if state=="playing" and is_instance_valid(player) and absf(player.position.x-pos.x)<65:
		draw_rect(Rect2(pos+Vector2(-45,-129),Vector2(90,19)),Color("14242d"))
		draw_string(FONT,pos+Vector2(-37,-115),"E  传递火种" if active else "完成本区目标",HORIZONTAL_ALIGNMENT_LEFT,-1,10,TEAL if active else AMBER)

func _draw_furnace() -> void:
	var pos: Vector2 = Vector2(1840,300)
	draw_rect(Rect2(pos+Vector2(-95,-168),Vector2(190,168)),Color("232e36"))
	draw_rect(Rect2(pos+Vector2(-105,-172),Vector2(210,9)),Color("39464c"))
	draw_rect(Rect2(pos+Vector2(-74,-155),Vector2(148,140)),Color("1a2730"))
	for x: int in [-63,63]:
		draw_rect(Rect2(pos+Vector2(x-5,-210),Vector2(10,210)),Color("46514f"))
		draw_rect(Rect2(pos+Vector2(x-9,-211),Vector2(18,8)),Color("60685d"))
	var fire: Color = Color("5c5345") if boss_defeated else Color("da8555")
	draw_circle(pos+Vector2(0,-92),43,Color("3b4343"))
	draw_circle(pos+Vector2(0,-92),35,Color("14242b"))
	draw_circle(pos+Vector2(0,-92),29,fire.darkened(0.35))
	draw_circle(pos+Vector2(0,-92),20,fire)
	for i: int in range(5):
		draw_rect(Rect2(pos+Vector2(-37+i*17,-136),Vector2(6,88)),Color("303d42"))
	draw_string(FONT,pos+Vector2(-43,-148),"F U R N A C E",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9a9480"))

func _capture(label: String) -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	screenshot.save_png("res://tests/"+label+".png")
	print("CAPTURE_OK: "+label)
	get_tree().quit()

func _smoke_test() -> void:
	await get_tree().process_frame
	start_game()
	assert(state=="world_map","New journey opens the atlas")
	campaign.action("depart")
	await get_tree().physics_frame
	await get_tree().physics_frame
	director.difficulty = 1
	assert(player.health==6,"Initial health")
	assert(enemies.size()==2,"Chapter one population")
	assert(platforms.size()==10,"Chapter one collision platforms")
	player.invulnerable = 0
	player.hurt(1,player.position+Vector2(30,0))
	assert(player.health==5,"Player damage")
	player.invulnerable = 0
	player.energy = 0
	for enemy: Node in enemies.duplicate():
		enemy.hurt(999,Vector2.ZERO)
	director.cleared = 2
	assert(gate_open(),"Kill goal opens gate")
	campaign.travel_to(1)
	assert(chapter==1 and damage_bonus==0,"Subareas carry progress without free attribute growth")
	await get_tree().physics_frame
	player.invulnerable = 0
	player.hurt(99,player.position)
	assert(state=="dead","Death state")
	respawn()
	assert(state=="playing" and player.health==player.max_health,"Retry restores character")
	campaign.travel_to(2)
	assert(is_instance_valid(boss),"Final boss spawned")
	await get_tree().physics_frame
	boss_awake = true
	boss.hurt(999,Vector2.ZERO)
	assert(boss_defeated and gate_open(),"First boss defeat opens chapter reward")
	choose_upgrade(1)
	assert(state=="world_map" and campaign.unlocked==1 and bonus_health==1,"First chapter unlocks second major region")
	campaign.travel_to(3)
	assert(chapter==3 and player.max_health==7,"Health growth is capped and persists")
	campaign.travel_to(5)
	assert(boss.kind=="tempest","Second chapter has its own boss")
	boss_awake = true
	boss.hurt(999,Vector2.ZERO)
	assert(boss_defeated and gate_open(),"Second boss opens final route")
	_complete_run()
	assert(state=="victory","Adventure can be completed")
	return_to_menu()
	assert(state=="menu","Return to menu")
	await get_tree().process_frame
	await get_tree().process_frame
	print("SMOKE_TEST_PASS: atlas, two regions, growth caps, combat, death, respawn, two bosses, victory, menu")
	get_tree().quit()

func _notification(what: int) -> void:
	if not is_instance_valid(director): return
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		director.save_campaign()
		get_tree().quit()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and state=="playing" and not test_mode:
		state = "paused"

