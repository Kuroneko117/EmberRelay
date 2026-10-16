extends CharacterBody2D
const ART = preload("res://scripts/art.gd")
## The four furnace constructs. All attacks have an explicit warning and recovery.

var game: Node
var kind: String = "scout"
var max_health: float = 4
var health: float = 4
var dead: bool = false
var facing: int = -1
var phase: int = 1

var age: float = 0.0
var home: Vector2 = Vector2.ZERO
var mode: String = "idle"
var timer: float = 0.6
var cooldown: float = 0.9
var flash: float = 0.0
var stun: float = 0.0
var knock_velocity: float = 0.0
var attack_kind: String = ""
var attack_hit: bool = false
var attack_index: int = 0
var attack_aim: Vector2 = Vector2.LEFT
var warning_time: float = 0.6
var phase_pulse: float = 0.0
var floor_check: float = 0.0
var safe_to_step: bool = true

const INK: Color = Color("0a1020")
const ARMOR: Color = Color("253448")
const EDGE: Color = Color("4b6472")
const LIGHT: Color = Color("829b9d")
const FIRE: Color = Color("ff724c")
const HOT: Color = Color("ffdd8a")
const RED: Color = Color("ed476f")


func setup(type: String, where: Vector2, owner_game: Node) -> void:
	kind = type
	position = where
	home = where
	game = owner_game
	match kind:
		"guard": max_health = 14
		"drone": max_health = 5
		"boss": max_health = 132
		"sentry": max_health = 10
		_: max_health = 7
	if game.chapter>=3 and kind!="boss": max_health *= 1.2
	if kind=="boss" and game.director.difficulty==0: max_health = 112
	health = max_health
	cooldown = 0.8 if kind != "boss" else 1.6


func _ready() -> void:
	# Also support callers assigning fields directly before add_child().
	if home == Vector2.ZERO:
		home = position
	if kind == "boss" and max_health == 4:
		max_health = 48
		health = max_health
	elif kind == "guard" and max_health == 4:
		max_health = 9
		health = max_health
	elif kind == "drone" and max_health == 4:
		max_health = 3
		health = max_health
	collision_layer = 4
	collision_mask = 1
	z_index = 12
	var hitbox: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	if kind == "boss":
		rectangle.size = Vector2(36, 54)
		hitbox.position = Vector2(0, -27)
	elif kind == "drone":
		rectangle.size = Vector2(24, 18)
		hitbox.position = Vector2(0, -13)
	else:
		rectangle.size = Vector2(18, 26)
		hitbox.position = Vector2(0, -13)
	hitbox.shape = rectangle
	add_child(hitbox)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	flash = maxf(0.0, flash - delta)
	phase_pulse = maxf(0.0, phase_pulse - delta)
	queue_redraw()
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	var player: CharacterBody2D = game.player as CharacterBody2D
	if game.state != "playing" or game.hit_pause>0:
		return
	if kind == "boss" and not game.boss_awake:
		velocity = Vector2(0, minf(velocity.y + 1000.0 * delta, 600.0))
		move_and_slide()
		return
	var offset: Vector2 = player.position - position
	if absf(offset.x) > 650.0:
		return
	if position.y > 600.0:
		_die()
		return
	if kind != "drone":
		velocity.y = minf(velocity.y + 1000.0 * delta, 600.0)
	if kind!="boss" and absf(offset.x)>310:
		velocity.x = 0
		if kind!="drone": move_and_slide()
		return
	cooldown = maxf(0.0, cooldown - delta)
	stun = maxf(0.0, stun - delta)
	knock_velocity = move_toward(knock_velocity, 0.0, 520.0 * delta)
	floor_check -= delta
	if floor_check <= 0.0 and kind != "drone":
		floor_check = 0.1
		var ray_start: Vector2 = position + Vector2(float(facing) * 24.0, -6.0)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_start + Vector2(0, 38), 1)
		safe_to_step = not get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	if stun > 0.0:
		velocity.x = knock_velocity
		move_and_slide()
		return
	if mode == "idle":
		facing = 1 if offset.x > 0.0 else -1
	match kind:
		"scout": _scout(delta, offset)
		"guard": _guard(delta, offset)
		"drone": _drone(delta, offset)
		"boss": _boss(delta, offset)
		"sentry": _sentry(delta,offset)
	if kind != "drone" and is_on_floor() and not safe_to_step and mode != "active":
		velocity.x = 0.0
	velocity.x += knock_velocity
	move_and_slide()
	if kind == "boss":
		position.x = clampf(position.x, game.campaign.arena_start()+30, game.level_width-90)
	elif kind=="drone":
		position.x = clampf(position.x,home.x-140,home.x+140)


func _scout(delta: float, offset: Vector2) -> void:
	if mode == "idle":
		velocity.x = float(facing) * 43.0 if absf(offset.x) > 59.0 else 0.0
		if absf(offset.x) < 110.0 and absf(offset.y) < 48.0 and cooldown <= 0.0:
			_warn("lunge", 0.48)
	elif mode == "warning":
		velocity.x = 0.0
		timer -= delta
		if timer <= 0.0:
			mode = "active"
			timer = 0.28
			_sfx("enemy_attack")
	elif mode == "active":
		velocity.x = float(facing) * 235.0 if safe_to_step else 0.0
		timer -= delta
		_try_hit(29.0, 30.0, 1, 170.0)
		if timer <= 0.0 or is_on_wall():
			_recover(0.6, 1.0)
	else:
		velocity.x = 0.0
		_tick_recovery(delta)


func _guard(delta: float, offset: Vector2) -> void:
	if mode == "idle":
		velocity.x = float(facing) * 29.0 if absf(offset.x) > 48.0 else 0.0
		if absf(offset.x) < 76.0 and absf(offset.y) < 45.0 and cooldown <= 0.0:
			_warn("slam", 0.7)
	elif mode == "warning":
		velocity.x = 0.0
		timer -= delta
		if timer <= 0.0:
			mode = "active"
			timer = 0.2
			game.fx_burst(position + Vector2(float(facing) * 29.0, -3.0), FIRE, 10)
			game.add_shake(3.0)
			_sfx("slam")
	elif mode == "active":
		velocity.x = float(facing) * 40.0
		timer -= delta
		_try_hit(61.0, 34.0, 1, 210.0)
		if timer <= 0.0:
			_recover(0.85, 1.3)
	else:
		velocity.x = 0.0
		_tick_recovery(delta)


func _drone(delta: float, offset: Vector2) -> void:
	velocity.y = (home.y + sin(age * 2.2) * 9.0 - position.y) * 3.0
	if mode == "idle":
		velocity.x = float(facing) * 27.0 if absf(offset.x) > 180.0 else -float(facing) * 15.0 if absf(offset.x) < 90.0 else 0.0
		if offset.length() < 330.0 and cooldown <= 0.0:
			attack_aim = (offset + Vector2(0, -15) - Vector2(0, -13)).normalized()
			_warn("shot", 0.65)
	elif mode == "warning":
		velocity.x = 0.0
		timer -= delta
		if timer <= 0.0:
			game.spawn_projectile(position + Vector2(0, -13) + attack_aim * 17.0, attack_aim * 145.0, 1, true, RED)
			game.fx_burst(position + Vector2(0, -13), RED, 5)
			_sfx("shoot")
			_recover(0.3, 1.9)
	else:
		velocity.x = 0.0
		_tick_recovery(delta)


func _boss(delta: float, offset: Vector2) -> void:
	if health <= max_health / 2 and phase == 1:
		phase = 2
		phase_pulse = 1.0
		game.fx_burst(position + Vector2(0, -32), RED, 28)
		game.add_shake(8.0)
		_sfx("boss_phase")
		_warn("phase", 0.95)
		game.director.say("核心过载！它的攻击变快了。跳过震地，抓住后摇反击！")
		game.director.ring(position-Vector2(0,36),RED,160)
	if mode == "idle":
		velocity.x = float(facing) * (36.0 if phase == 1 else 48.0) if absf(offset.x) > 100.0 else 0.0
		if cooldown <= 0.0:
			attack_index += 1
			if attack_index % 3 == 0:
				attack_aim = (offset + Vector2(0, 18)).normalized()
				_warn("fan", 0.9 if phase == 1 else 0.72)
			elif absf(offset.x) < 125.0:
				_warn("slam", 0.85 if phase == 1 else 0.68)
			else:
				_warn("rush", 0.95 if phase == 1 else 0.76)
	elif mode == "warning":
		velocity.x = 0.0
		timer -= delta
		if timer <= 0.0:
			mode = "active"
			attack_hit = false
			match attack_kind:
				"rush":
					timer = 0.65 if phase == 1 else 0.75
					_sfx("enemy_attack")
				"slam":
					timer = 0.22
					game.add_shake(8.0)
					game.fx_burst(position + Vector2(float(facing) * 35.0, -3), FIRE, 22)
					_sfx("slam")
					if phase==2:
						game.spawn_projectile(position+Vector2(-45,-8),Vector2(-190,0),1,true,RED)
						game.spawn_projectile(position+Vector2(45,-8),Vector2(190,0),1,true,RED)
				"fan":
					timer = 0.15
					var shot_count: int = 3 if phase == 1 else 5
					for i: int in range(shot_count):
						var angle: float = (float(i) - float(shot_count - 1) * 0.5) * 0.22
						var direction: Vector2 = attack_aim.rotated(angle)
						game.spawn_projectile(position + Vector2(0, -36) + direction * 25.0, direction * (155.0 if phase == 1 else 180.0), 1, true, FIRE if phase == 1 else RED)
					_sfx("shoot")
				_:
					timer = 0.15
	elif mode == "active":
		timer -= delta
		if attack_kind == "rush":
			velocity.x = float(facing) * (215.0 if phase == 1 else 270.0) if safe_to_step else 0.0
			_try_hit(40.0, 49.0, 2, 230.0)
			if is_on_wall():
				timer = 0.0
		elif attack_kind == "slam":
			velocity.x = 0.0
			_try_hit(110.0 if phase == 1 else 130.0, 32.0, 2, 230.0)
		else:
			velocity.x = 0.0
		if timer <= 0.0:
			_recover(0.9 if phase == 1 else 0.65, 1.25 if phase == 1 else 0.85)
	else:
		velocity.x = 0.0
		_tick_recovery(delta)


func _warn(which: String, duration: float) -> void:
	mode = "warning"
	attack_kind = which
	timer = duration
	warning_time = duration
	attack_hit = false
	_sfx("warning")


func _recover(duration: float, delay: float) -> void:
	mode = "recovery"
	timer = duration
	cooldown = delay


func _tick_recovery(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		mode = "idle"


func _try_hit(horizontal: float, vertical: float, amount: int, force: float) -> void:
	if attack_hit or not is_instance_valid(game.player):
		return
	var offset: Vector2 = game.player.position - position
	# Slams can be jumped; a construct never causes damage merely by touching it.
	if absf(offset.x) <= horizontal and absf(offset.y) < vertical:
		if attack_kind != "slam" and offset.x * float(facing) < -18.0:
			return
		if game.player.hurt(amount, position, force):
			attack_hit = true


func hurt(amount: float, knock: Vector2 = Vector2.ZERO) -> void:
	if dead or amount <= 0:
		return
	if kind == "boss" and not game.boss_awake:
		return
	health = maxf(0, health - amount*(1.12 if mode=="recovery" else 0.62) if kind=="boss" else health-amount)
	flash = 0.13
	var resistance: float = 0.22 if kind == "boss" else 0.5 if kind == "guard" else 1.0
	knock_velocity = knock.x * resistance
	if kind != "drone":
		velocity.y = minf(velocity.y, knock.y * resistance)
	# Small machines can be interrupted. The armoured guard and boss keep
	# their warnings visible, so repeated attacks cannot hide their next hit.
	if kind == "scout" or kind == "drone":
		stun = 0.13
		if mode == "warning":
			_recover(0.3, 0.6)
	if is_instance_valid(game):
		game.fx_burst(position + Vector2(0, -27 if kind == "boss" else -14), HOT, 8)
		game.add_shake(2.5 if kind == "boss" else 1.6)
		_sfx("enemy_hit")
	if health <= 0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	if is_instance_valid(game):
		game.presentation.death_effect(position-Vector2(0,26 if kind=="boss" else 15),kind=="boss")
		game.fx_burst(position + Vector2(0, -27 if kind == "boss" else -14), FIRE, 35 if kind == "boss" else 15)
		game.add_shake(9.0 if kind == "boss" else 2.5)
		_sfx("enemy_die")
		game.on_enemy_killed(self)
	queue_free()


func _sfx(sound_name: String) -> void:
	if is_instance_valid(game) and is_instance_valid(game.audio):
		game.audio.play_sfx(sound_name)


func _draw() -> void:
	var glow: Color = Color("78d8cd") if kind=="sentry" else RED if (kind == "drone" or phase == 2) else FIRE
	var body: Color = Color("fff1ce") if flash > 0.0 else ARMOR
	var edge: Color = Color.WHITE if flash > 0.0 else EDGE
	var warning: bool = mode == "warning"
	if warning and int(age * 15.0) % 2 == 0:
		glow = HOT
	# Attack footprints remain in world orientation and avoid covering sprites.
	if warning and (attack_kind == "slam" or attack_kind == "rush" or attack_kind == "lunge"):
		var reach: float = (130.0 if phase == 2 else 110.0) if kind == "boss" and attack_kind == "slam" else 61.0 if kind == "guard" else (203.0 if phase == 2 else 140.0) if attack_kind == "rush" else 69.0
		var start: float = -reach if attack_kind == "slam" else minf(0.0, float(facing) * reach)
		var width: float = reach * 2.0 if attack_kind == "slam" else reach
		draw_rect(Rect2(start, -3, width, 3), Color(glow, 0.26))
		var progress: float = 1.0 - clampf(timer / warning_time, 0.0, 1.0)
		draw_rect(Rect2(start, -2, width * progress, 2), Color(glow, 0.75))
	if mode == "active" and attack_kind == "slam":
		var reach: float = 130.0 if kind == "boss" and phase == 2 else 110.0 if kind == "boss" else 61.0
		draw_rect(Rect2(-reach, -6, reach * 2.0, 4), Color(glow, 0.75))
		for i: int in range(7):
			var xx: float = -reach + float(i) * reach / 3.0
			draw_rect(Rect2(xx, -14, 5, 9), Color(HOT, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0))
	match kind:
		"boss": _draw_boss(body, edge, glow, warning)
		"guard": _draw_atlas_enemy(glow,warning)
		"drone": _draw_atlas_enemy(glow,warning)
		_: _draw_atlas_enemy(glow,warning)
	draw_set_transform(Vector2.ZERO)
	if health < max_health and kind != "boss":
		var bar_y: float = -42.0 if kind == "guard" else -38.0
		draw_rect(Rect2(-13, bar_y, 26, 3), INK)
		draw_rect(Rect2(-12, bar_y + 1, 24.0 * float(health) / float(max_health), 1), glow)
	if warning:
		var top: float = -83.0 if kind == "boss" else -46.0 if kind == "guard" else -42.0
		draw_rect(Rect2(-1, top, 3, 7), HOT)
		draw_rect(Rect2(-1, top + 9, 3, 3), HOT)


func _draw_boss(body: Color, edge: Color, glow: Color, warning: bool) -> void:
	var stride: float = roundf(sin(age*9)*3) if absf(velocity.x)>5 else 0
	var breath: float = roundf(sin(age*2)*1)
	var pre: float = 1-clampf(timer/maxf(warning_time,0.01),0,1) if warning else 0
	draw_rect(Rect2(-32,-2,64,4),Color(INK,0.6))
	# Pistons, knee caps and grounded feet retain mass through the animation.
	for side: int in [-1,1]:
		var x: float = side*14
		var sy: float = stride*side
		draw_line(Vector2(x,-28),Vector2(x+side*3,-8+sy),INK,13)
		draw_line(Vector2(x-2,-25),Vector2(x+side*3-2,-7+sy),edge,4)
		draw_rect(Rect2(x-4,-19,3,9),glow.darkened(0.2))
		ART.stamp(self,Rect2(80,0,16,16),Rect2(x-7,-18,14,12),Color("b1bab0"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-11,-7+sy),Vector2(x+10,-7+sy),Vector2(x+14,-2+sy),Vector2(x+14,1+sy),Vector2(x-12,1+sy)]),INK)
		draw_line(Vector2(x-10,-5+sy),Vector2(x+11,-5+sy),edge,2)
	# Chamfered boiler shell, textured armour and rivets.
	draw_set_transform(Vector2(0,breath),0,Vector2(float(facing),1))
	draw_colored_polygon(PackedVector2Array([Vector2(-29,-57),Vector2(-20,-64),Vector2(20,-64),Vector2(29,-56),Vector2(26,-23),Vector2(16,-18),Vector2(-20,-18),Vector2(-28,-25)]),INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-26,-55),Vector2(-18,-61),Vector2(18,-61),Vector2(26,-54),Vector2(23,-26),Vector2(14,-21),Vector2(-18,-21),Vector2(-25,-27)]),body)
	ART.stamp(self,Rect2(288,0,48,16),Rect2(-24,-53,48,15),Color("acb6a7") if flash<=0 else Color.WHITE)
	draw_line(Vector2(-21,-58),Vector2(20,-58),edge,2)
	for side: int in [-1,1]:
		var x: float = side*23
		draw_colored_polygon(PackedVector2Array([Vector2(x-8,-57),Vector2(x+6,-57),Vector2(x+10,-50),Vector2(x+8,-38),Vector2(x-8,-38)]),edge)
		draw_rect(Rect2(x-5,-54,10,3),Color("a5b4ad"))
		for yy: int in [-51,-43]: draw_rect(Rect2(x-5,yy,2,2),INK)
	# Smokestacks hiss continuously; overloading changes both heat and silhouette.
	for i: int in range(2):
		var x: float = -22+i*11
		var h: float = 21+i*7
		ART.stamp(self,Rect2(272,0,16,64),Rect2(x,-58-h,7,h),Color("bbc4b0"))
		draw_rect(Rect2(x,-58-h,7,3),glow)
		for j: int in range(3):
			var rise: float = fposmod(age*(17+phase*6)+j*8,25)
			draw_rect(Rect2(x+sin(age*2+j)*3,-60-h-rise,4+rise*0.15,3),Color(glow if phase==2 else edge,0.32*(1-rise/25)))
	draw_rect(Rect2(-15,-47,30,25),INK)
	draw_rect(Rect2(-12,-45,24,20),glow.darkened(0.18))
	draw_rect(Rect2(-9,-42,18,15),glow)
	draw_rect(Rect2(-5,-38,10,10),HOT)
	draw_rect(Rect2(-2,-36,4,7),Color("fff6d2"))
	for i: int in range(5): draw_rect(Rect2(-12+i*5,-46,2,22),body)
	draw_line(Vector2(-15,-23),Vector2(15,-23),edge,2)
	# Slit-eyed head turns slightly into the selected attack.
	var head_y: float = -68+(3*pre if warning and attack_kind=="rush" else 0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6,head_y),Vector2(16,head_y),Vector2(23,head_y+6),Vector2(20,head_y+16),Vector2(-6,head_y+16)]),INK)
	draw_rect(Rect2(-3,head_y+3,21,10),body)
	draw_rect(Rect2(1,head_y+7,20,3),glow)
	draw_rect(Rect2(18,head_y+4,3,3),HOT)
	draw_line(Vector2(-5,head_y+1),Vector2(17,head_y+1),edge,2)
	# The hammer lifts on anticipation, accelerates into impact and settles in recovery.
	var arm_angle: float = -0.1
	if warning and attack_kind=="slam": arm_angle = lerpf(-0.1,-2.55,pre*pre)
	elif mode=="active" and attack_kind=="slam": arm_angle = -0.55
	elif warning and attack_kind=="fan": arm_angle = -1.4
	elif mode=="active" and attack_kind=="rush": arm_angle = -0.7
	draw_set_transform(Vector2(27*facing,-48+breath),arm_angle*facing,Vector2(float(facing),1))
	draw_line(Vector2.ZERO,Vector2(0,25),INK,10)
	draw_line(Vector2(-2,2),Vector2(-2,24),edge,4)
	draw_line(Vector2(2,4),Vector2(2,23),Color("a6b7b1"),2)
	draw_rect(Rect2(-13,22,29,18),INK)
	ART.stamp(self,Rect2(80,0,16,16),Rect2(-11,24,25,13),Color("cfceaf"))
	draw_rect(Rect2(-11,36,25,4),glow)
	draw_rect(Rect2(-7,25,3,10),edge)
	draw_rect(Rect2(8,25,3,10),edge)
	draw_set_transform(Vector2.ZERO,0,Vector2(float(facing),1))
	if phase_pulse>0:
		draw_arc(Vector2(0,-36),48+(1-phase_pulse)*50,0,TAU,32,Color(glow,phase_pulse*0.6),2)
	if mode=="recovery":
		for i: int in range(3): draw_rect(Rect2(-10+i*7,-80-sin(age*4+i)*3,2,2),Color("92b6b5"))


func _draw_atlas_enemy(glow: Color, warning: bool) -> void:
	var frame: int = int(age*9)%4
	var row: int = 368
	var size: float = 32
	if kind=="guard":
		row = 400
		size = 42
	elif kind=="drone":
		row = 432
		size = 32
	if mode=="idle" and absf(velocity.x)<4: frame = int(age*4)%2
	if warning: frame = 1
	var tint: Color = Color("fff3da") if flash>0 else Color("ddd8c3")
	ART.stamp(self,Rect2(frame*16,row,16,16),Rect2(-size/2,-size+(3 if warning and kind!="drone" else 0),size,size),tint)
	if kind=="sentry":
		# A braced base and long aimable barrel distinguish ranged sentries at a glance.
		draw_rect(Rect2(-13,-5,26,5),Color("344f59"))
		draw_line(Vector2(-10,-2),Vector2(-16,1),Color("85a6a2"),2)
		draw_line(Vector2(10,-2),Vector2(16,1),Color("85a6a2"),2)
		var muzzle: Vector2 = Vector2(0,-18)+Vector2(absf(attack_aim.x),attack_aim.y)*24
		draw_line(Vector2(1,-18),muzzle,INK,7)
		draw_line(Vector2(1,-19),muzzle-Vector2(0,1),Color("93aaa3"),3)
		draw_circle(muzzle,3,glow)
		if warning: draw_line(muzzle,muzzle+Vector2(absf(attack_aim.x),attack_aim.y)*75,Color(glow,0.35),1)
	if warning:
		draw_circle(Vector2(2,-size*0.58),8,Color(glow,0.12))
		draw_line(Vector2(9,-size*0.58),Vector2(21,-size*0.58-7),glow,2)
	if mode=="active" and kind!="drone":
		draw_colored_polygon(PackedVector2Array([Vector2(8,-17),Vector2(30,-12),Vector2(9,-7)]),Color(glow,0.8))

func _sentry(delta: float,offset: Vector2) -> void:
	velocity.x = 0
	if mode=="idle":
		if offset.length()<330 and cooldown<=0:
			attack_aim = (offset-Vector2(0,15)).normalized()
			_warn("shot",0.85)
	elif mode=="warning":
		timer -= delta
		if timer<=0:
			for angle: float in [-0.12,0,0.12]:
				var direction: Vector2 = attack_aim.rotated(angle)
				game.spawn_projectile(position-Vector2(0,18)+direction*19,direction*195,1,true,Color("78d8cd"))
			_sfx("shoot")
			_recover(0.65,1.8)
	else: _tick_recovery(delta)

