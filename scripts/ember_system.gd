extends Node2D
## Fire is earned through play, then spent either on a burst or an optional relay.
const GOLD = Color("efb473")
const TEAL = Color("79d8cc")
const FONT = preload("res://assets/ui_font.ttc")
const CORE = preload("res://assets/ui/items/burst.png")
const BOX = preload("res://assets/art/water-control-box-1.png")
const COST: float = 60
const NAMES = ["返流线圈", "破甲棘轮", "悬浮喷口"]
const ITEMS = ["pulse", "blade", "beacon"]
const DETAILS = ["完美弹反后，下一发脉冲\n变为 5 点伤害，只耗 14 能量。\n8 秒内有效，不能叠加。",
	"第三段近战命中恢复 10 共鸣。\n额外打断普通重装守卫。\n每次挥击仅触发一次。",
	"每次离地后的首次空中射击\n悬停 0.16 秒，冲刺冷却缩短。\n落地后重新装填。"]
var game: Node
var lit: Array[int] = []
var module: int = -1
var lessons: Dictionary = {}
var charged: float = 0
var air_spent: bool = false
var hover: float = 0
var pending_sector: int = -1
var lesson_text: String = ""
var age: float = 0

func _ready() -> void: z_index = 11

func reset() -> void:
	lit.clear()
	module = -1
	lessons.clear()
	charged = 0
	air_spent = false
	hover = 0
	game.director.focus = 20

func position_for(sector: int = -1) -> Vector2:
	return [Vector2(1355,193),Vector2(1370,204),Vector2(1220,248),Vector2(2198,151),Vector2(2155,139),Vector2(2306,145)][game.chapter if sector<0 else sector]

func sector_loaded() -> void:
	charged = 0
	hover = 0
	air_spent = false
	pending_sector = -1
	lesson_text = ""
	age = 0
	ensure_bypass()

func snapshot() -> Dictionary:
	return {"lit":lit.duplicate(),"module":module,"lessons":lessons.duplicate()}

func restore(data: Dictionary) -> void:
	lit.clear()
	for value: Variant in data.get("lit",[]):
		if int(value)>=0 and int(value)<6 and not lit.has(int(value)): lit.append(int(value))
	module = clampi(int(data.get("module",-1)),-1,2)
	lessons = data.get("lessons",{}).duplicate()
	ensure_bypass()
	game.stats_changed.emit()

func gain(amount: float) -> void:
	game.director.focus = minf(100,game.director.focus+amount)

func mark(key: String) -> void: lessons[key] = true

func on_parry() -> void:
	mark("parry")
	gain(10)
	if module==0:
		charged = 8
		game.floating_number(game.player.position-Vector2(0,56),"返流就绪",TEAL)

func on_third_hit(enemy: Node) -> void:
	if module!=1: return
	if enemy.kind=="guard" and not enemy.dead:
		enemy.stun = 0.45
		enemy.mode = "recovery"
		enemy.timer = 0.45
		game.floating_number(enemy.position-Vector2(0,48),"破甲",GOLD)

func on_shot() -> void:
	mark("pulse")
	if module==2 and not game.player.is_on_floor() and not air_spent:
		air_spent = true
		hover = 0.16
		game.player.velocity.y = 0
		game.player.dash_cooldown = maxf(0,game.player.dash_cooldown-0.3)
		game.fx_burst(game.player.position+Vector2(0,2),TEAL,9)

func safe_to_use() -> bool:
	return game.director.active_arena<0 and not (game.boss_awake and not game.boss_defeated)

func try_interact() -> bool:
	var distance: float = game.player.position.distance_to(position_for())
	if distance>38: return false
	for chest: Dictionary in game.director.chests:
		if not chest.open and game.player.position.distance_to(chest.pos)<distance: return false
	if not safe_to_use():
		game.show_notice("先解除当前封锁，再接通支路中继")
		return true
	if not lit.has(game.chapter) and game.director.focus<COST:
		game.show_notice("支路中继需要 60 共鸣 · 近战与弹反蓄能 · 不影响主路通行")
		return true
	pending_sector = game.chapter
	game.state = "attunement"
	return true

func equip(which: int) -> void:
	if game.state!="attunement" or pending_sector!=game.chapter or which<0 or which>2: return
	if not safe_to_use(): return
	if not lit.has(pending_sector):
		if game.director.focus<COST: return
		game.director.focus -= COST
		lit.append(pending_sector)
		game.run_score += 250
	module = which
	charged = 0
	mark("relay")
	ensure_bypass()
	game.state = "playing"
	game.audio.play_sfx("checkpoint")
	game.director.ring(position_for()-Vector2(0,18),TEAL,70)
	game.fx_burst(position_for()-Vector2(0,18),TEAL,22)
	game.stats_changed.emit()
	queue_redraw()
	game.show_notice("装配「%s」 · 已点亮的中继可免费更换"%NAMES[module])
	game.director.save_campaign()

func ensure_bypass() -> void:
	if game.chapter!=1 or not lit.has(1) or not is_instance_valid(game.world): return
	if game.world.has_node("RelayBypass"): return
	var rect: Rect2 = Rect2(1378,274,112,14)
	game.platforms.append(rect)
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "RelayBypass"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	shape.one_way_collision = true
	body.add_child(shape)
	game.world.add_child(body)

func tick(delta: float) -> void:
	age += delta
	charged = maxf(0,charged-delta)
	hover = maxf(0,hover-delta)
	if game.player.is_on_floor(): air_spent = false
	if game.chapter==0 and game.player.position.x>200: mark("move")
	var text: String = ""
	if game.controls.lessons_enabled and game.chapter<3:
		if not lessons.has("move"): text = "%s 移动  ·  %s 跳跃，再按可二段跳"%[game.controls.prompt("move_right"),game.controls.prompt("jump")]
		elif not lessons.has("hit") and game.player.position.x>250: text = "%s 连斩蓄能  ·  第三击破开包围"%game.controls.prompt("attack")
		elif not lessons.has("dash") and game.player.position.x>550: text = "%s 冲刺穿过攻击  ·  冲刺期间无敌"%game.controls.prompt("dash")
		elif game.player.health<game.player.max_health and game.director.potions>0 and not lessons.has("heal"): text = "%s 修复两格生命  ·  中继站补充修复剂"%game.controls.prompt("heal")
		elif not lit.has(game.chapter) and absf(game.player.position.x-position_for().x)<230: text = "高处火种：%s 接通中继  ·  60 共鸣换装配，或留给爆发"%game.controls.prompt("interact")
		elif game.director.focus>=100 and not lessons.has("burst"): text = "%s 余烬爆发：击退敌人并反射附近弹幕"%game.controls.prompt("burst")
		elif not lessons.has("parry"):
			for foe: Node in game.enemies:
				if is_instance_valid(foe) and not foe.dead and foe.mode=="warning" and foe.position.distance_to(game.player.position)<145:
					text = "%s 弹反即将到来的攻击  ·  成功恢复能量和共鸣"%game.controls.prompt("parry")
	if lesson_text!=text:
		lesson_text = text
		game.stats_changed.emit()
	queue_redraw()

func _draw() -> void:
	if game.state=="menu" or not is_instance_valid(game.player): return
	var pos: Vector2 = position_for()
	if absf(pos.x-game.camera.position.x)>380: return
	var on: bool = lit.has(game.chapter)
	var col: Color = TEAL if on else GOLD
	# Both components come from the existing industrial / inventory art families.
	draw_texture_rect(BOX,Rect2(pos-Vector2(15,20),Vector2(30,20)),false,Color("b0c5bb"))
	draw_line(pos-Vector2(0,20),pos-Vector2(0,31),col,2)
	draw_texture_rect(CORE,Rect2(pos-Vector2(10,48+sin(age*2)*2),Vector2(20,20)),false)
	draw_circle(pos-Vector2(0,36),14,Color(col,0.07))
	var near: bool = game.player.position.distance_to(pos)<65
	if near:
		var caption: String = "%s 更换装配 · 免费"%game.controls.prompt("interact") if on else "%s 点燃中继 · 60 / %d"%[game.controls.prompt("interact"),int(game.director.focus)]
		draw_rect(Rect2(pos-Vector2(88,77),Vector2(176,19)),Color("0b1b23"))
		draw_string(FONT,pos-Vector2(82,64),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,9,col)
	else:
		draw_string(FONT,pos-Vector2(21,57),"支路中继",HORIZONTAL_ALIGNMENT_LEFT,-1,8,col)
