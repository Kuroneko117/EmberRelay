extends CharacterBody2D
const COURIER = preload("res://scripts/courier_art.gd")
const PALETTE = preload("res://scripts/visual_palette.gd")

## The approved human courier; gameplay position is the feet.
var game: Node
var facing: int = 1
var max_health: int = 6
var health: int = 6:
	set(value):
		if health==value: return
		health = value
		if is_instance_valid(game): game.stats_changed.emit()
var energy: float = 100.0:
	set(value):
		if energy==value: return
		energy = value
		if is_instance_valid(game): game.stats_changed.emit()
var invulnerable: float = 0.0
var dash_cooldown: float = 0.0
var dead: bool = false

const SPEED: float = 174.0
const GRAVITY: float = 1050.0
const JUMP_SPEED: float = -352.0
const DASH_SPEED: float = 420.0
const IVORY: Color = PALETTE.PAPER
const SHADOW_IVORY: Color = PALETTE.LIGHT
const INK: Color = PALETTE.INK
const ARMOR: Color = PALETTE.STEEL
const EMBER: Color = PALETTE.ORANGE
const LIGHT: Color = PALETTE.SIGNAL_LIGHT
const CYAN: Color = PALETTE.SIGNAL

var _clock: float = 0.0
var _walk_clock: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jumps_used: int = 0
var _dash_time: float = 0.0
var _dash_direction: float = 1.0
var _dash_trail_clock: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_timer: float = 0.0
var _attack_duration: float = 0.18
var _attack_hit_delay: float = 0.045
var _attack_elapsed: float = 0.0
var _attack_pending: bool = false
var _combo: int = 0
var _combo_window: float = 0.0
var _pulse_cooldown: float = 0.0
var _pulse_pose_time: float = 0.0
var _pulse_buffer: float = 0.0
var _shot_facing: int = 1
var _knockback_timer: float = 0.0
var _landed_last_frame: bool = false
var _land_time: float = 0.0
var _ghosts: Array[Dictionary] = []
var parry_time: float = 0
var parry_cooldown: float = 0
var _attack_buffer: float = 0
var _drop_time: float = 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 5.0
	floor_stop_on_slope = true
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(14.0, 28.0)
	collider.shape = shape
	collider.position = Vector2(0.0, -14.0)
	add_child(collider)
	z_index = 12
	queue_redraw()


func reset_at(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	health = max_health
	energy = 100.0
	invulnerable = 0.0
	dash_cooldown = 0.0
	dead = false
	facing = 1
	_coyote = 0.0
	_jump_buffer = 0.0
	_jumps_used = 0
	_dash_time = 0.0
	_attack_cooldown = 0.0
	_attack_timer = 0.0
	_attack_pending = false
	_attack_hit_delay = 0.045
	_land_time = 0
	_combo = 0
	_combo_window = 0.0
	_pulse_cooldown = 0.0
	_pulse_pose_time = 0.0
	_pulse_buffer = 0.0
	if is_instance_valid(game.combat_fx): game.combat_fx.clear_actor()
	_knockback_timer = 0.0
	_ghosts.clear()
	parry_time = 0
	parry_cooldown = 0
	_attack_buffer = 0
	_drop_time = 0
	collision_mask = 1
	queue_redraw()


func buffer_attack() -> void:
	if dead or game==null or game.state!="playing": return
	var reserve: float = minf(0.34,_attack_cooldown+0.03) if game.hit_pause>0 else maxf(0.16,_pulse_pose_time+0.03)
	_attack_buffer = maxf(_attack_buffer,maxf(reserve,_pulse_pose_time+0.03))


func buffer_pulse() -> void:
	if dead or game==null or game.state!="playing": return
	_pulse_buffer = maxf(_pulse_buffer,minf(0.4,maxf(0.14,maxf(_attack_timer,_pulse_cooldown)+0.03)))

func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing" or dead:
		queue_redraw()
		return
	if Input.is_action_just_pressed("attack"): buffer_attack()
	if Input.is_action_just_pressed("pulse"): buffer_pulse()
	if game.hit_pause>0:
		queue_redraw()
		return
	_clock += delta
	_walk_clock += delta * absf(velocity.x) / SPEED * 12.0
	invulnerable = maxf(0.0, invulnerable - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_combo_window = maxf(0.0, _combo_window - delta)
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)
	_pulse_pose_time = maxf(0.0,_pulse_pose_time-delta)
	_pulse_buffer = maxf(0,_pulse_buffer-delta)
	_knockback_timer = maxf(0.0, _knockback_timer - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	parry_time = maxf(0,parry_time-delta)
	parry_cooldown = maxf(0,parry_cooldown-delta)
	_attack_buffer = maxf(0,_attack_buffer-delta)
	_drop_time = maxf(0,_drop_time-delta)
	_land_time = maxf(0,_land_time-delta)
	if _drop_time<=0: collision_mask = 1
	energy = minf(100.0, energy + delta * 8.0)
	_update_ghosts(delta)

	var grounded: bool = is_on_floor()
	if grounded:
		_coyote = 0.11
		_jumps_used = 0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		if _coyote <= 0.0 and _jumps_used == 0:
			_jumps_used = 1
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.13
		if grounded and Input.is_action_pressed("down") and position.y<290:
			_drop_time = 0.19
			collision_mask = 0
			position.y += 5
			velocity.y = 100
			_jump_buffer = 0
			_coyote = 0
	if Input.is_action_just_pressed("parry") and parry_cooldown<=0 and _knockback_timer<=0:
		_pulse_pose_time = 0
		game.combat_fx.clear_actor()
		parry_time = 0.21 if game.director.difficulty==0 else 0.16
		parry_cooldown = 0.85
		_attack_pending = false
		_attack_timer = 0
		game.audio.play_sfx("guard")

	var direction: float = Input.get_axis("move_left", "move_right")
	if absf(direction)>0.1: _land_time = 0
	if absf(direction) > 0.1 and _dash_time <= 0.0 and _pulse_pose_time<=0:
		facing = 1 if direction > 0.0 else -1

	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and _knockback_timer <= 0.0:
		_start_dash(direction)
	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
		velocity = Vector2(_dash_direction * DASH_SPEED, 0.0)
		_dash_trail_clock -= delta
		if _dash_trail_clock <= 0.0:
			_dash_trail_clock = 0.025
			_ghosts.append({"position": global_position, "facing": facing, "life": 0.20})
		move_and_slide()
		queue_redraw()
		return

	if _knockback_timer <= 0.0:
		var target_speed: float = direction * SPEED
		if _attack_timer > 0.0 and grounded:
			target_speed *= 0.75
		var acceleration: float = 1350.0 if grounded else 940.0
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)
	if game.flame.hover>0: velocity.y = 0

	if _jump_buffer > 0.0 and (_coyote > 0.0 or _jumps_used < 2) and _knockback_timer <= 0.0:
		_do_jump()
	if Input.is_action_just_released("jump") and velocity.y < -120.0:
		velocity.y *= 0.53

	if (Input.is_action_pressed("attack") or _attack_buffer>0) and _attack_cooldown <= 0.0 and _knockback_timer <= 0.0 and parry_time<=0 and _pulse_pose_time<=0:
		_attack_buffer = 0
		_start_attack()
	var pulse_cost: float = 14.0 if game.flame.module==0 and game.flame.charged>0 else 28.0
	if (Input.is_action_pressed("pulse") or _pulse_buffer>0) and _pulse_cooldown <= 0.0 and energy >= pulse_cost and _knockback_timer <= 0.0 and parry_time<=0 and _attack_timer<=0:
		_fire_pulse()
	if _attack_pending:
		_attack_elapsed = _attack_duration-_attack_timer
		if _attack_elapsed+0.00001 >= _attack_hit_delay:
			_attack_pending = false
			_perform_melee()

	var falling_speed: float = velocity.y
	move_and_slide()
	if is_on_floor() and not _landed_last_frame and falling_speed > 170.0:
		game.fx_burst(global_position + Vector2(0.0, -2.0), Color("a3aca7"), 5)
		if _attack_timer<=0 and _dash_time<=0 and parry_time<=0:
			_land_time = 0.14
	_landed_last_frame = is_on_floor()
	queue_redraw()


func _do_jump() -> void:
	_land_time = 0
	game.flame.mark("jump")
	var extra_jump: bool = _jumps_used > 0 and _coyote <= 0.0
	velocity.y = JUMP_SPEED * (0.92 if extra_jump else 1.0)
	_jumps_used += 1
	_coyote = 0.0
	_jump_buffer = 0.0
	game.audio.play_sfx("jump")
	game.fx_burst(global_position + Vector2(0.0, -2.0), CYAN if extra_jump else Color("bbc8c0"), 8 if extra_jump else 5)


func _start_dash(direction: float) -> void:
	_pulse_pose_time = 0
	_pulse_buffer = 0
	game.combat_fx.clear_actor()
	_land_time = 0
	game.flame.mark("dash")
	_dash_direction = direction if absf(direction) > 0.1 else float(facing)
	_dash_direction = signf(_dash_direction)
	facing = int(_dash_direction)
	_dash_time = 0.15
	dash_cooldown = 0.95
	invulnerable = maxf(invulnerable, 0.23)
	_dash_trail_clock = 0.0
	_attack_timer = 0.0
	_attack_pending = false
	game.audio.play_sfx("dash")
	game.fx_burst(global_position + Vector2(0.0, -14.0), CYAN, 8)


func _start_attack() -> void:
	if _pulse_pose_time>0 or dead or game.state!="playing": return
	_land_time = 0
	_combo = (_combo % 3) + 1 if _combo_window > 0.0 else 1
	_combo_window = 0.65
	_attack_cooldown = 0.31 if _combo == 3 else 0.22
	_attack_duration = 0.23 if _combo == 3 else 0.18
	_attack_hit_delay = 0.075 if _combo==3 else 0.045
	_attack_timer = _attack_duration
	if _pulse_buffer>0: _pulse_buffer = maxf(_pulse_buffer,_attack_duration+0.03)
	_attack_elapsed = 0.0
	_attack_pending = true
	game.audio.play_sfx("slash")
	if is_on_floor():
		velocity.x += float(facing) * 40.0


func _perform_melee() -> void:
	if is_instance_valid(game.combat_fx): game.combat_fx.slash(global_position,facing,_combo)
	var reach: float = 52.0 if _combo == 3 else 43.0
	var attack_x: float = -3.0 if facing > 0 else -reach + 3.0
	var attack_box: Rect2 = Rect2(global_position + Vector2(attack_x, -36.0), Vector2(reach, 34.0))
	var damage: int = 3 if _combo == 3 else 2
	game.player_melee(attack_box, damage, Vector2(float(facing) * (210.0 if _combo == 3 else 130.0), -65.0), _combo)


func _fire_pulse() -> void:
	if _attack_timer>0 or _dash_time>0 or parry_time>0 or _knockback_timer>0 or _pulse_cooldown>0 or dead or game.state!="playing": return
	var empowered: bool = game.flame.module==0 and game.flame.charged>0
	var cost: float = 14.0 if empowered else 28.0
	if energy<cost: return
	energy -= cost
	game.flame.charged = 0
	game.flame.on_shot()
	_pulse_cooldown = 0.37
	_pulse_buffer = 0
	_pulse_pose_time = 0.18
	_shot_facing = facing
	var origin: Vector2 = pulse_muzzle()
	var aim: Vector2 = Vector2(facing,0)
	var nearest: float = 260
	for enemy: Node in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var offset: Vector2 = enemy.position-Vector2(0,18)-origin
		if offset.x*facing>0 and absf(offset.y)<110 and offset.length()<nearest:
			nearest = offset.length()
			aim = offset.normalized()
	var resolved: Vector2 = game.launch_player_pulse(global_position+Vector2(0,-17),origin,aim*(440 if empowered else 365),5 if empowered else 3,EMBER if empowered else CYAN)
	if resolved.distance_to(origin)<1: game.combat_fx.muzzle(origin,facing) # Occluded extension makes an impact only, never a fake chest muzzle.
	game.audio.play_sfx("pulse")
	queue_redraw() # Recoil is a 2px visual offset only; never changes physical motion.


func hurt(amount: int, source: Vector2, force: float = 140.0) -> bool:
	if dead or game == null or game.state != "playing":
		return false
	if parry_time>0 and force>0:
		parry_time = 0
		game.director.parry(source)
		return false
	if invulnerable>0: return false
	if game.director.difficulty==2 and force>0: amount += 1
	health = maxi(0, health - amount)
	invulnerable = 1.3 if game.director.difficulty==0 else 0.9
	_pulse_pose_time = 0
	_pulse_buffer = 0
	game.combat_fx.clear_actor()
	_knockback_timer = 0.18
	_land_time = 0
	_dash_time = 0.0
	_attack_pending = false
	_attack_timer = 0.0
	var push_direction: float = signf(global_position.x - source.x)
	if push_direction == 0.0:
		push_direction = -float(facing)
	velocity = Vector2(push_direction * force, -175.0)
	game.audio.play_sfx("hurt")
	game.fx_burst(global_position + Vector2(0.0, -16.0), EMBER, 12)
	game.on_player_hurt()
	if health <= 0:
		dead = true
		game.on_player_died()
	queue_redraw()
	return true


func _update_ghosts(delta: float) -> void:
	for i: int in range(_ghosts.size() - 1, -1, -1):
		_ghosts[i]["life"] = float(_ghosts[i]["life"]) - delta
		if float(_ghosts[i]["life"]) <= 0.0:
			_ghosts.remove_at(i)


func pulse_recoil() -> Vector2:
	if _pulse_pose_time<=0: return Vector2.ZERO
	var phase: float = (0.18-_pulse_pose_time)/0.18
	return Vector2(-float(_shot_facing)*roundf(sin(phase*PI)*2),0)

func pulse_muzzle() -> Vector2:
	return global_position+Vector2(COURIER.PULSE_MUZZLE.x*facing,COURIER.PULSE_MUZZLE.y)+pulse_recoil()

func _draw() -> void:
	for ghost: Dictionary in _ghosts:
		draw_set_transform(ghost.position-global_position,0,Vector2(float(ghost.facing),1))
		COURIER.draw_pose(self,"run",int(_walk_clock),Color(0.35,0.94,0.9,float(ghost.life)/0.2*0.4))
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	if dead:
		draw_set_transform(Vector2.ZERO,0,Vector2(float(facing),1))
		COURIER.draw_pose(self,"death",0)
		draw_set_transform(Vector2.ZERO)
		return
	if invulnerable>0 and int(_clock*20)%2==0 and _dash_time<=0: return
	var running: bool = absf(velocity.x)>15 and is_on_floor()
	var pose: String = "run" if running else "idle"
	var frame: int = int(_clock*6) if not running else int(_walk_clock*1.05)
	if _land_time>0 and is_on_floor() and not running:
		pose = "land"
		frame = clampi(int((0.14-_land_time)/0.14*4.0),0,3)
	if not is_on_floor():
		pose = "rise" if velocity.y< -90 else "apex" if velocity.y<90 else "fall"
		frame = 0
	if _pulse_pose_time>0:
		pose = "pulse"
		frame = 0
	if _attack_timer>0:
		pose = "attack3" if _combo==3 else "attack2" if _combo==2 else "attack"
		frame = COURIER.attack_frame(_attack_duration-_attack_timer,_attack_duration,_combo)
	if parry_time>0:
		pose = "parry"
		frame = 0
	if _dash_time>0:
		pose = "dash"
		frame = 0
	if _knockback_timer>0:
		pose = "hurt"
		frame = 0
	draw_set_transform(pulse_recoil(),0,Vector2(float(facing),1))
	# Hair, face, lantern, scarf, coat, hands and blade are all in the new drawings.
	COURIER.draw_pose(self,pose,frame)
	draw_set_transform(Vector2.ZERO)
	if parry_time>0:
		var center: Vector2 = Vector2(facing*5,-19)
		draw_arc(center,26,-1.4 if facing>0 else 1.74,1.4 if facing>0 else 4.54,20,Color(CYAN,0.28),5)
		draw_arc(center,29,-1.3 if facing>0 else 1.84,1.3 if facing>0 else 4.44,20,LIGHT,2)

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-10,-1,20,2),Color(0.02,0.04,0.08,0.35))


