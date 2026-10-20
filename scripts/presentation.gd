extends Node2D
## Authored ambience, destructible scenery and the quiet moments between encounters.
const ART = preload("res://scripts/art.gd")
const FONT = preload("res://assets/ui_font.ttc")
const DEATH = preload("res://assets/art/enemy-death.png")
const HIT = preload("res://assets/art/impact.png")
var game: Node
var crates: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var time: float = 0
var sector_title: float = 0
var memorials: Array[Dictionary] = []
var interacted: Dictionary = {}
var birds: Array[Dictionary] = []
var lift: AnimatableBody2D
var lift_shape: CollisionShape2D
var lift_y: float = 300
var lift_target: float = 300
var lift_on: bool = false
var circuit_on: bool = false
var mechanism: Vector2
var finale: float = 0
var explosions: Array[Dictionary] = []
var relays: Array[Dictionary] = []

func _ready() -> void:
	z_index = 15

func configure() -> void:
	crates.clear()
	impacts.clear()
	explosions.clear()
	memorials.clear()
	interacted.clear()
	birds.clear()
	sector_title = 4.5
	lift_y = 300
	lift_target = 300
	lift_on = false
	circuit_on = false
	finale = 0
	relays.clear()
	mechanism = [Vector2(390,300),Vector2(495,300),Vector2(1335,300)][game.chapter%3]
	lift = AnimatableBody2D.new()
	lift.collision_layer = 1
	lift.collision_mask = 0
	lift.sync_to_physics = true
	lift_shape = CollisionShape2D.new()
	var platform: RectangleShape2D = RectangleShape2D.new()
	platform.size = Vector2(62 if game.chapter==0 else 104,10)
	lift_shape.shape = platform
	lift_shape.position = Vector2(0,5)
	lift_shape.one_way_collision = true
	lift.add_child(lift_shape)
	game.world.add_child(lift)
	lift.position = Vector2(393,300) if game.chapter==0 else Vector2(582,300)
	lift_shape.disabled = game.chapter!=0
	for x: float in [[205,605,810,1305,1740,2180],[170,370,710,1260,1690,2230],[205,710,1120,1390]][game.chapter%3]:
		crates.append({"pos":Vector2(x,300),"hp":2,"broken":false})
	var quotes: Array = [
		["末班车停在了这里。有人把车票折成了纸鸟。","留给下一位旅人：灯塔还亮着，请不要放弃。"],
		["雨水会带走锈迹，带不走曾经在这里生活的人。","管廊第 7 号记录：把光送出去，比守住它更重要。"],
		["守护协议最后一行：直到最后一颗火种安全离开。","如果你读到了这里，替我们看看黎明。"]]
	for i: int in range(2):
		memorials.append({"pos":Vector2(315+i*1040,300),"text":quotes[game.chapter%3][i]})
	if game.chapter==0:
		for i: int in range(4): birds.append({"pos":Vector2(145+i*11,293),"flying":false,"age":0.0})
	if game.chapter>=3:
		crates.clear()
		for x: int in range(210,int(game.level_width)-170,340):
			var grounded: bool = false
			for floor_rect: Rect2 in game.platforms:
				if floor_rect.size.y>30 and x>floor_rect.position.x+20 and x<floor_rect.end.x-20: grounded = true
			if grounded: crates.append({"pos":Vector2(x,300),"hp":2,"broken":false})
		mechanism = Vector2(490,300) if game.chapter==3 else Vector2(1120,213) if game.chapter==4 else Vector2(2570,300)
		if game.chapter==3:
			lift_shape.shape.size = Vector2(125,10)
			lift.position = Vector2(688,300)
			lift_shape.disabled = true
		if game.chapter==4:
			relays = [{"pos":Vector2(1120,213),"on":false},{"pos":Vector2(2940,168),"on":false}]
		var messages: Array = [["船坞日志：涨潮后，请使用升起的运输步道。","最后一艘补给船仍然停在北岸，货舱里有通向灯塔的信号。"],
			["断弦高架的两座校准台，一座在旧站台，一座在高处天线旁。","空中的雷光不是星星。等它们落下，你才能看见真正的路。"],
			["织机仍在按照早已失效的指令引导风暴。让它停下来。","信使，灯塔看见你了。把这场长夜留在身后。"]]
		memorials.clear()
		for i: int in range(2): memorials.append({"pos":Vector2(315+i*1610,300),"text":messages[game.chapter-3][i]})
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	if game.state=="playing":
		finale = maxf(0,finale-delta)
		sector_title = maxf(0,sector_title-delta)
		for i: int in range(impacts.size()-1,-1,-1):
			impacts[i].life -= delta
			if impacts[i].life<=0: impacts.remove_at(i)
		for i: int in range(explosions.size()-1,-1,-1):
			explosions[i].life -= delta
			if explosions[i].life<=0: explosions.remove_at(i)
		for bird: Dictionary in birds:
			if bird.flying:
				bird.age += delta
				bird.pos += Vector2(66,-37)*delta
	queue_redraw()

func tick(_delta: float) -> void:
	if game.chapter==0 and is_instance_valid(lift):
		lift_y = move_toward(lift_y,lift_target,_delta*56)
		lift.position = Vector2(393,lift_y)
	if game.chapter==4:
		var nearest: float = INF
		for relay: Dictionary in relays:
			if game.player.position.distance_to(relay.pos)<nearest:
				nearest = game.player.position.distance_to(relay.pos)
				mechanism = relay.pos
	if game.player.position.distance_to(mechanism)<55 and _mechanism_is_closest() and Input.is_action_just_pressed("interact"):
		if game.chapter>=3:
			_activate_new_mechanism()
		elif game.chapter==0:
			lift_on = true
			lift_target = 198 if lift_target>250 else 300
			game.director.say("运输升降台恢复了。站上去，看看上层还留下了什么。")
		elif not circuit_on:
			circuit_on = true
			if game.chapter==1:
				lift_shape.set_deferred("disabled",false)
				game.director.say("水力桥已通电。青色步道连接了两岸。继续向灯塔前进。")
			else:
				game.director.focus = minf(100,game.director.focus+30)
				game.director.say("备用核心已释放，余烬蓄能补充。信使，接下来就交给你了。")
			game.embers += 3
			game.director.save_campaign()
		game.audio.play_sfx("checkpoint")
		game.director.ring(mechanism-Vector2(0,26),Color("7be3cf"),75)
		game.stats_changed.emit()
	for bird: Dictionary in birds:
		if not bird.flying and absf(bird.pos.x-game.player.position.x)<65:
			bird.flying = true
	for plaque: Dictionary in memorials:
		if game.player.position.distance_to(plaque.pos)<40 and game.player.position.distance_to(plaque.pos)<game.player.position.distance_to(mechanism) and Input.is_action_just_pressed("interact"):
			game.director.say(plaque.text)
			if not interacted.has(plaque.text):
				interacted[plaque.text] = true
				game.run_score += 50
				game.audio.play_sfx("pickup")

func strike(area: Rect2, damage: int) -> void:
	for crate: Dictionary in crates:
		if crate.broken or not area.intersects(Rect2(crate.pos-Vector2(13,25),Vector2(26,25))): continue
		crate.hp -= damage
		impact(crate.pos-Vector2(0,13),true)
		if crate.hp<=0:
			crate.broken = true
			game.audio.play_sfx("enemy_die")
			game.fx_burst(crate.pos-Vector2(0,12),Color("aab1a4"),15)
			for dx: int in [-7,0,7]: game._add_pickup(crate.pos+Vector2(dx,-20),"ember")
			game.floating_number(crate.pos-Vector2(9,28),"余烬 +3",Color("eab777"))

func impact(pos: Vector2, heavy: bool) -> void:
	impacts.append({"pos":pos,"life":0.19,"heavy":heavy})

func death_effect(pos: Vector2, heavy: bool) -> void:
	explosions.append({"pos":pos,"life":0.5,"heavy":heavy})

func snapshot() -> Dictionary:
	var broken: Array[bool] = []
	for crate: Dictionary in crates: broken.append(crate.broken)
	return {"broken":broken,"circuit":circuit_on,"lift":lift_on,"target":lift_target,"messages":interacted.duplicate(),"relays":relays.duplicate(true)}

func restore(data: Dictionary) -> void:
	if data.is_empty(): return
	var broken: Array = data.get("broken",[])
	for i: int in range(mini(broken.size(),crates.size())): crates[i].broken = broken[i]
	circuit_on = data.get("circuit",false)
	lift_on = data.get("lift",false)
	lift_target = float(data.get("target",300))
	interacted = data.get("messages",{})
	if game.chapter in [1,3] and circuit_on: lift_shape.set_deferred("disabled",false)
	if data.has("relays"): relays.assign(data.relays)

func _draw() -> void:
	if game.state=="menu" or not is_instance_valid(game.player): return
	_draw_mechanism()
	_draw_route_markers()
	for crate: Dictionary in crates:
		if absf(crate.pos.x-game.camera.position.x)>355: continue
		if crate.broken:
			ART.stamp(self,Rect2(80,0,16,16),Rect2(crate.pos-Vector2(14,5),Vector2(29,6)),Color("6e7b78"))
		else:
			ART.stamp(self,Rect2(80,0,16,16),Rect2(crate.pos-Vector2(13,26),Vector2(26,26)),Color("bdc2b0"))
			draw_rect(Rect2(crate.pos+Vector2(-6,-17),Vector2(12,2)),Color("e0a66b"))
	for plaque: Dictionary in memorials:
		var p: Vector2 = plaque.pos
		draw_line(p,p-Vector2(0,29),Color("445b64"),3)
		draw_rect(Rect2(p-Vector2(12,33),Vector2(24,16)),Color("202c36"))
		draw_rect(Rect2(p-Vector2(10,31),Vector2(20,1)),Color("879b97"))
		for i: int in range(3): draw_line(p+Vector2(-7,-27+i*3),p+Vector2(6-i*2,-27+i*3),Color("70938d"),1)
		if p.distance_to(game.player.position)<42 and p.distance_to(game.player.position)<mechanism.distance_to(game.player.position):
			draw_string(FONT,p-Vector2(24,41),game.controls.prompt("interact")+"  旧日留言",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("c7d4bd"))
	for bird: Dictionary in birds:
		var p: Vector2 = bird.pos
		var wing: float = sin(bird.age*24)*4 if bird.flying else 0
		draw_line(p-Vector2(5,3+wing),p,Color("c2b9a2"),1)
		draw_line(p,p+Vector2(5,-3-wing),Color("c2b9a2"),1)
		draw_rect(Rect2(p-Vector2(2,1),Vector2(4,2)),Color("202735"))
	for hit: Dictionary in impacts:
		var t: float = hit.life/0.19
		var radius: float = (26 if hit.heavy else 17)*(1-t)+4
		var hit_frame: int = clampi(int((1-t)*4),0,3)
		var hit_size: float = 25 if hit.heavy else 18
		draw_texture_rect_region(HIT,Rect2(hit.pos-Vector2.ONE*hit_size/2,Vector2.ONE*hit_size),Rect2(hit_frame*12,0,12,12),Color(1,1,1,t))
		for i: int in range(8):
			var dir: Vector2 = Vector2.from_angle(i*TAU/8+0.2)
			draw_line(hit.pos+dir*radius*0.4,hit.pos+dir*radius,Color("fff0b9")*Color(1,1,1,t),2 if hit.heavy else 1)
		draw_circle(hit.pos,3*t,Color("fff5d5"))
	for effect: Dictionary in explosions:
		var frame: int = clampi(int((0.5-effect.life)*10),0,4)
		var size: Vector2 = Vector2(67,48)*(2.0 if effect.heavy else 0.9)
		draw_texture_rect_region(DEATH,Rect2(effect.pos-size/2,size),Rect2(frame*67,0,67,48))

func _draw_mechanism() -> void:
	if game.chapter>=3:
		_draw_new_mechanism()
		return
	if game.chapter==0:
		for x: float in [363,423]:
			ART.stamp(self,Rect2(272,0,16,64),Rect2(x,188,6,112),Color("8c9f98"))
		ART.tile_strip(self,Rect2(0,0,64,16),Vector2(362,lift_y),62,12,Color("c5c0a6"))
		for y: int in range(202,298,10):
			draw_rect(Rect2(365,y,2,5),Color("70b5aa") if lift_on else Color("616f6f"))
	elif game.chapter==1:
		for x: int in [538,623]:
			ART.stamp(self,Rect2(272,0,16,64),Rect2(x,279,5,58),Color("a5ae97"))
		if circuit_on:
			ART.tile_strip(self,Rect2(0,0,64,16),Vector2(530,300),104,12,Color("a4ddd1"))
			draw_line(Vector2(534,300),Vector2(628,300),Color("b5f1d8"),2)
			for i: int in range(10): draw_rect(Rect2(534+i*10,288,1,12),Color("54766f"))
	# The machine is recognizable before its text prompt appears.
	var p: Vector2 = mechanism-Vector2(36,0)
	draw_texture_rect(preload("res://assets/art/water-control-box-1.png"),Rect2(p-Vector2(16,21),Vector2(32,21)),false,Color("a4bcb4"))
	draw_rect(Rect2(p-Vector2(2,2),Vector2(4,3)),Color("607e80"))
	var active: bool = lift_on if game.chapter==0 else circuit_on
	draw_rect(Rect2(p+Vector2(-10,-16),Vector2(6,8)),Color("7be3cf") if active else Color("b4a278"))
	draw_line(p+Vector2(10,-14),p+Vector2(19,-23 if active else -6),Color("e6b475"),2)
	if active:
		draw_circle(p-Vector2(0,23),25,Color(0.3,0.85,0.7,0.045))
	if game.player.position.distance_to(mechanism)<62 and _mechanism_is_closest():
		var label: String = "E  运输升降台" if game.chapter==0 else "E  水力桥供电" if game.chapter==1 else "E  释放备用核心"
		if active and game.chapter!=0: label = "供电完成" if game.chapter==1 else "备用核心已释放"
		draw_rect(Rect2(mechanism-Vector2(63,61),Vector2(126,18)),Color("101e29"))
		draw_string(FONT,mechanism-Vector2(55,48),label.replace("E ",game.controls.prompt("interact")+" "),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b7ded0"))

func _mechanism_is_closest() -> bool:
	var distance: float = game.player.position.distance_to(mechanism)
	for plaque: Dictionary in memorials:
		if game.player.position.distance_to(plaque.pos)<distance: return false
	return true

func _activate_new_mechanism() -> void:
	if game.chapter==4:
		for relay: Dictionary in relays:
			if relay.pos==mechanism and not relay.on:
				relay.on = true
				game.embers += 3
		var count: int = 0
		for relay: Dictionary in relays:
			if relay.on: count += 1
		circuit_on = count==2
		game.director.say("信标 %d / 2 已接通。"%count+("向右穿过中继门，进入风暴之眼。" if circuit_on else "下一座信标已标在区域地图，按 C 查看。"))
	elif not circuit_on:
		circuit_on = true
		if game.chapter==3:
			lift_shape.set_deferred("disabled",false)
			game.director.say("船坞供电已恢复。运输步道升起，主航线现在可以通行。")
		else:
			game.director.focus = minf(100,game.director.focus+30)
			game.director.say("备用电池接入，积蓄余烬 +30。风暴的中心就在前方。")
		game.embers += 3
	game.director.save_campaign()
	game.stats_changed.emit()

func _draw_route_markers() -> void:
	if not is_instance_valid(game.guide): return
	for device: Dictionary in game.guide.devices():
		var p: Vector2 = device.pos-Vector2(0,82 if game.chapter==4 else 68)
		var col: Color = Color("83c8bc") if device.on else Color("ecb371")
		draw_line(p+Vector2(0,15),device.pos-Vector2(0,34),Color(col,0.35),1)
		draw_rect(Rect2(p-Vector2(13,10),Vector2(26,21)),Color("0c1d26"))
		draw_rect(Rect2(p-Vector2(13,10),Vector2(26,21)),Color(col,0.7),false,1)
		draw_string(FONT,p+Vector2(-5,5),"✓" if device.on else device.id,HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)
		if not device.on:
			var pulse: float = 0.35+sin(time*3.0)*0.18
			draw_arc(p,18,-2.7,-0.4,14,Color(col,pulse),1)
	# Put a clear entry sign at each boss threshold, before the encounter locks.
	if game.campaign.is_boss_sector() and not game.boss_awake and not game.boss_defeated:
		var p: Vector2 = Vector2(game.campaign.arena_start()-42,192)
		draw_texture_rect(preload("res://assets/ui/items/beacon.png"),Rect2(p-Vector2(18,22),Vector2(36,36)),false)
		draw_string(FONT,p+Vector2(-30,20),"守卫区 →",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("ecb371"))
		draw_string(FONT,p+Vector2(-38,35),"向前进入战斗",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("b3ccc6"))

func _draw_new_mechanism() -> void:
	if game.chapter==3:
		if circuit_on:
			ART.tile_strip(self,Rect2(0,0,64,16),Vector2(625,300),125,12,Color("9bc4b9"))
			draw_line(Vector2(627,300),Vector2(746,300),Color("96e5cf"),2)
		for x: int in [636,740]: ART.stamp(self,Rect2(272,0,16,64),Rect2(x,284,5,70),Color("6d9294"))
	var points: Array = relays if game.chapter==4 else [{"pos":mechanism,"on":circuit_on}]
	for relay: Dictionary in points:
		var p: Vector2 = relay.pos
		var tex: Texture2D = preload("res://assets/art/water-control-box-1.png")
		draw_texture_rect(tex,Rect2(p-Vector2(16,30),Vector2(32,30)),false,Color("a7c3b8"))
		var col: Color = Color("83e0c9") if relay.on else Color("d5a16b")
		draw_rect(Rect2(p-Vector2(5,23),Vector2(10,9)),col)
		if game.chapter==4:
			draw_line(p-Vector2(0,31),p-Vector2(0,66),Color("6f9397"),3)
			draw_arc(p-Vector2(0,61),11,-2.7,-0.4,16,col,2)
		if relay.on:
			draw_circle(p-Vector2(0,20),26,Color(col,0.05))
		if game.player.position.distance_to(p)<55:
			var label: String = "E 校准信标" if game.chapter==4 else "E 船坞供电" if game.chapter==3 else "E 备用电池"
			if relay.on: label = "信标已接通" if game.chapter==4 else "能源已接通"
			var prompt: Vector2 = p+Vector2(-52,8) if game.chapter==4 else p-Vector2(52,48)
			draw_rect(Rect2(prompt,Vector2(108,19)),Color("111e28"))
			draw_string(FONT,prompt+Vector2(6,13),label.replace("E ",game.controls.prompt("interact")+" "),HORIZONTAL_ALIGNMENT_LEFT,-1,10,col)
