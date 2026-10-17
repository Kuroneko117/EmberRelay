extends CharacterBody2D
## The Storm Loom: aerial pressure, telegraphed lightning and grounded counterattack windows.
const VISUAL = preload("res://scripts/enemy_visual.gd")
var visual: AnimatedSprite2D
var satellites: Array[AnimatedSprite2D] = []
const TEAL = Color("70dfd9")
const GOLD = Color("f5c384")
const RED = Color("ed6d83")
var game: Node
var kind: String = "tempest"
var max_health: float = 176
var health: float = 176:
	set(value):
		health = value
		if is_instance_valid(game): game.stats_changed.emit()
var dead: bool = false
var facing: int = -1
var phase: int = 1
var age: float = 0
var home: Vector2
var mode: String = "idle"
var timer: float = 1
var cooldown: float = 1.4
var flash: float = 0
var stun: float = 0
var knock_velocity: float = 0
var attack_kind: String = ""
var attack_hit: bool = false
var attack_index: int = 0
var attack_aim: Vector2 = Vector2.LEFT
var warning_time: float = 0.8
var phase_pulse: float = 0
var lightning: Array[Dictionary] = []
var shots_left: int = 0
var shot_timer: float = 0
var dive_direction: float = -1

func combat_size() -> Vector2:
	return Vector2(54,48)

func setup(_type: String,where: Vector2,owner_game: Node) -> void:
	game = owner_game
	position = where
	home = where
	if game.director.difficulty==0: max_health = 152
	health = max_health

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 12
	var c: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(42,50)
	c.position = Vector2(0,-25)
	c.shape = shape
	add_child(c)
	visual = VISUAL.new()
	visual.configure(self,"tempest")
	add_child(visual)
	for i: int in range(4):
		var satellite: AnimatedSprite2D = AnimatedSprite2D.new()
		satellite.sprite_frames = VISUAL.frames_for("drone")
		satellite.offset = Vector2(0,-24)
		satellite.scale = Vector2.ONE*0.45
		satellite.play("move")
		satellite.position = Vector2.from_angle(i*TAU/4)*43+Vector2(0,-24)
		add_child(satellite)
		satellites.append(satellite)

func _physics_process(delta: float) -> void:
	age += delta
	for i: int in range(satellites.size()):
		satellites[i].position = Vector2.from_angle(i*TAU/4+sin(age*0.7)*0.14)*43+Vector2(0,-24)
		satellites[i].modulate = Color("f3b17b") if phase==3 else Color.WHITE
		satellites[i].visible = not dead
	flash = maxf(0,flash-delta)
	phase_pulse = maxf(0,phase_pulse-delta)
	queue_redraw()
	if dead or game.state!="playing" or game.hit_pause>0: return
	if not game.boss_awake:
		position.y = home.y+sin(age*1.7)*4
		return
	stun = minf(maxf(0,stun-delta),0.14)
	for i: int in range(lightning.size()-1,-1,-1):
		var bolt: Dictionary = lightning[i]
		bolt.life -= delta
		if bolt.life<=0:
			lightning.remove_at(i)
			continue
		if bolt.life<0.65 and absf(game.player.position.x-bolt.x)<13 and game.player.position.y>105:
			game.player.hurt(2,Vector2(bolt.x,300),0)
	var new_phase: int = 3 if health<=max_health*0.30 else 2 if health<=max_health*0.65 else 1
	if new_phase>phase:
		phase = new_phase
		phase_pulse = 1
		game.director.say("电场在收束。落雷即将显形，俯冲落地后是它的破绽！")
		game.director.ring(position-Vector2(0,26),TEAL,150)
		game.audio.play_sfx("boss_phase")
	var offset: Vector2 = game.player.position-position
	facing = 1 if offset.x>0 else -1
	cooldown = maxf(0,cooldown-delta)
	if mode=="idle":
		velocity = Vector2(clampf(offset.x*0.35,-46,46),(home.y+sin(age*1.8)*10-position.y)*2)
		if cooldown<=0:
			attack_index += 1
			_warn("dive" if attack_index%3==0 else "storm" if attack_index%3==2 else "volley")
	elif mode=="warning":
		timer -= delta
		velocity = Vector2.ZERO
		if timer<=0: _activate()
	elif mode=="active":
		timer -= delta
		if attack_kind=="dive":
			velocity = Vector2(dive_direction*(310+phase*24),(294-position.y)*6)
			if not attack_hit and absf(offset.x)<48 and absf(offset.y)<42:
				attack_hit = game.player.hurt(2,position,210)
		elif attack_kind=="volley":
			velocity = Vector2.ZERO
			shot_timer -= delta
			if shots_left>0 and shot_timer<=0:
				shots_left -= 1
				shot_timer = 0.27
				var aim: Vector2 = (game.player.position-Vector2(0,18)-(position-Vector2(0,25))).normalized()
				for j: int in range(3 if phase<3 else 5):
					var count: int = 3 if phase<3 else 5
					var direction: Vector2 = aim.rotated((j-(count-1)/2.0)*0.23)
					game.spawn_projectile(position-Vector2(0,25)+direction*34,direction*(160+phase*12),1,true,TEAL)
				game.audio.play_sfx("shoot")
		else: velocity = Vector2.ZERO
		if timer<=0:
			mode = "recovery"
			timer = 1.15 if attack_kind=="dive" else 0.65
			cooldown = 0.65 if phase==3 else 0.95
	elif mode=="recovery":
		timer -= delta
		velocity = Vector2(0,0 if attack_kind=="dive" else (home.y-position.y)*2)
		if timer<=0:
			mode = "idle"
			lightning.clear()
	move_and_slide()
	position.x = clampf(position.x,game.campaign.arena_start()+65,game.level_width-155)
	position.y = clampf(position.y,170,295)

func _warn(which: String) -> void:
	attack_kind = which
	mode = "warning"
	warning_time = 0.85 if phase==1 else 0.73 if phase==2 else 0.62
	if which=="storm": warning_time += 0.25
	timer = warning_time
	attack_hit = false
	game.audio.play_sfx("warning")
	if which=="storm":
		lightning.clear()
		var px: float = clampf(game.player.position.x,game.campaign.arena_start()+55,game.level_width-165)
		for dx: int in [-110,0,110]:
			lightning.append({"x":clampf(px+dx,game.campaign.arena_start()+30,game.level_width-140),"life":warning_time+0.65})
		if phase==3:
			lightning.append({"x":clampf(px+220,game.campaign.arena_start()+30,game.level_width-140),"life":warning_time+0.9})
	elif which=="dive": dive_direction = float(facing)

func _activate() -> void:
	mode = "active"
	match attack_kind:
		"volley":
			shots_left = 2 if phase==1 else 3
			shot_timer = 0
			timer = shots_left*0.27+0.2
		"storm": timer = 0.8
		"dive":
			timer = 1.0
			game.audio.play_sfx("enemy_attack")

func hurt(amount: float,knock: Vector2=Vector2.ZERO) -> void:
	if dead or not game.boss_awake or amount<=0: return
	var multiplier: float = 1.18 if mode=="recovery" else 0.62
	health = maxf(0,health-amount*multiplier)
	flash = 0.10
	knock_velocity = knock.x*0.1
	game.fx_burst(position-Vector2(0,26),GOLD,5)
	game.audio.play_sfx("enemy_hit")
	if health<=0:
		dead = true
		lightning.clear()
		for satellite: AnimatedSprite2D in satellites: satellite.hide()
		game.presentation.death_effect(position-Vector2(0,25),true)
		game.on_enemy_killed(self)
		set_physics_process(false)
		set_deferred("collision_layer",0)
		get_child(0).set_deferred("disabled",true)

func _draw() -> void:
	if dead: return
	var center: Vector2 = Vector2(0,-26)
	var glow: Color = RED if phase==3 else TEAL
	for bolt: Dictionary in lightning:
		var x: float = bolt.x-position.x
		var active: bool = bolt.life<0.65
		draw_rect(Rect2(x-12,90-position.y,24,210),Color(glow,0.2 if active else 0.065))
		draw_line(Vector2(x-16,298-position.y),Vector2(x+16,298-position.y),glow,3 if active else 1)
		if active:
			var pts: PackedVector2Array = PackedVector2Array()
			for j: int in range(12): pts.append(Vector2(x+sin(j*7+age*45)*7,90+j*19-position.y))
			draw_polyline(pts,GOLD,2)
		else:
			draw_line(Vector2(x,285-position.y),Vector2(x,273-position.y),glow,2)
	if mode=="warning" and attack_kind=="dive":
		draw_rect(Rect2(minf(0,dive_direction*340),285-position.y,340,9),Color(glow,0.18))
	if mode=="warning":
		draw_arc(center,61,-PI/2,-PI/2+TAU*(1-timer/warning_time),40,Color(glow,0.75),1)
	if mode=="recovery":
		for i: int in range(4): draw_rect(Rect2(-12+i*8,-68-sin(age*4+i)*3,2,2),GOLD)
