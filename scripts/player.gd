extends CharacterBody2D
const COURIER = preload("res://scripts/courier_art.gd")

## Small, responsive, fully procedural player character. Position is the feet.
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
const IVORY: Color = Color("f3edd5")
const SHADOW_IVORY: Color = Color("b3b7a5")
const INK: Color = Color("151f35")
const ARMOR: Color = Color("344b61")
const EMBER: Color = Color("ff9e57")
const LIGHT: Color = Color("a3fff0")
const CYAN: Color = Color("54dddb")

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
var _attack_elapsed: float = 0.0
var _attack_pending: bool = false
var _combo: int = 0
var _combo_window: float = 0.0
var _pulse_cooldown: float = 0.0
var _knockback_timer: float = 0.0
var _landed_last_frame: bool = false
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
	_combo = 0
	_combo_window = 0.0
	_pulse_cooldown = 0.0
	_knockback_timer = 0.0
	_ghosts.clear()
	parry_time = 0
	parry_cooldown = 0
	_attack_buffer = 0
	_drop_time = 0
	collision_mask = 1
	queue_redraw()


func _physics_process(delta: float) -> void:
	if game == null or game.state != "playing" or dead:
		queue_redraw()
		return
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
	_knockback_timer = maxf(0.0, _knockback_timer - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	parry_time = maxf(0,parry_time-delta)
	parry_cooldown = maxf(0,parry_cooldown-delta)
	_attack_buffer = maxf(0,_attack_buffer-delta)
	_drop_time = maxf(0,_drop_time-delta)
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
	if Input.is_action_just_pressed("attack"): _attack_buffer = 0.16
	if Input.is_action_just_pressed("parry") and parry_cooldown<=0 and _knockback_timer<=0:
		parry_time = 0.21 if game.director.difficulty==0 else 0.16
		parry_cooldown = 0.85
		_attack_pending = false
		_attack_timer = 0
		game.audio.play_sfx("guard")

	var direction: float = Input.get_axis("move_left", "move_right")
	if absf(direction) > 0.1 and _dash_time <= 0.0:
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

	if _jump_buffer > 0.0 and (_coyote > 0.0 or _jumps_used < 2) and _knockback_timer <= 0.0:
		_do_jump()
	if Input.is_action_just_released("jump") and velocity.y < -120.0:
		velocity.y *= 0.53

	if (Input.is_action_pressed("attack") or _attack_buffer>0) and _attack_cooldown <= 0.0 and _knockback_timer <= 0.0 and parry_time<=0:
		_attack_buffer = 0
		_start_attack()
	if Input.is_action_pressed("pulse") and _pulse_cooldown <= 0.0 and energy >= 28.0 and _knockback_timer <= 0.0 and parry_time<=0:
		_fire_pulse()
	if _attack_pending:
		_attack_elapsed += delta
		if _attack_elapsed >= 0.045:
			_attack_pending = false
			_perform_melee()

	var falling_speed: float = velocity.y
	move_and_slide()
	if is_on_floor() and not _landed_last_frame and falling_speed > 170.0:
		game.fx_burst(global_position + Vector2(0.0, -2.0), Color("a3aca7"), 5)
	_landed_last_frame = is_on_floor()
	queue_redraw()


func _do_jump() -> void:
	var extra_jump: bool = _jumps_used > 0 and _coyote <= 0.0
	velocity.y = JUMP_SPEED * (0.92 if extra_jump else 1.0)
	_jumps_used += 1
	_coyote = 0.0
	_jump_buffer = 0.0
	game.audio.play_sfx("jump")
	game.fx_burst(global_position + Vector2(0.0, -2.0), CYAN if extra_jump else Color("bbc8c0"), 8 if extra_jump else 5)


func _start_dash(direction: float) -> void:
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
	_combo = (_combo % 3) + 1 if _combo_window > 0.0 else 1
	_combo_window = 0.65
	_attack_cooldown = 0.31 if _combo == 3 else 0.22
	_attack_duration = 0.23 if _combo == 3 else 0.18
	_attack_timer = _attack_duration
	_attack_elapsed = 0.0
	_attack_pending = true
	game.audio.play_sfx("slash")
	if is_on_floor():
		velocity.x += float(facing) * 40.0


func _perform_melee() -> void:
	var reach: float = 52.0 if _combo == 3 else 43.0
	var attack_x: float = -3.0 if facing > 0 else -reach + 3.0
	var attack_box: Rect2 = Rect2(global_position + Vector2(attack_x, -36.0), Vector2(reach, 34.0))
	var damage: int = 3 if _combo == 3 else 2
	game.player_melee(attack_box, damage, Vector2(float(facing) * (210.0 if _combo == 3 else 130.0), -65.0), _combo)
	if _combo == 3:
		game.add_shake(1.0)


func _fire_pulse() -> void:
	energy -= 28.0
	_pulse_cooldown = 0.37
	var origin: Vector2 = global_position + Vector2(float(facing)*13,-17)
	var aim: Vector2 = Vector2(facing,0)
	var nearest: float = 260
	for enemy: Node in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var offset: Vector2 = enemy.position-Vector2(0,18)-origin
		if offset.x*facing>0 and absf(offset.y)<110 and offset.length()<nearest:
			nearest = offset.length()
			aim = offset.normalized()
	game.spawn_projectile(origin,aim*365,3,false,CYAN)
	game.fx_burst(global_position + Vector2(float(facing) * 15.0, -17.0), LIGHT, 6)
	game.audio.play_sfx("pulse")
	game.add_shake(1.2)
	velocity.x -= float(facing) * 38.0


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
	_knockback_timer = 0.18
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


func _draw() -> void:
	for ghost: Dictionary in _ghosts:
		draw_set_transform(ghost.position-global_position,0,Vector2(float(ghost.facing),1))
		COURIER.draw_pose(self,"run",int(_walk_clock),Color(0.35,0.94,0.9,float(ghost.life)/0.2*0.4))
	draw_set_transform(Vector2.ZERO)
	draw_ellipse_shadow()
	if dead:
		draw_set_transform(Vector2(-13,-6),PI/2,Vector2.ONE)
		COURIER.draw_pose(self,"hurt",1,Color("b7ada0"))
		draw_set_transform(Vector2.ZERO)
		return
	if invulnerable>0 and int(_clock*20)%2==0 and _dash_time<=0: return
	var running: bool = absf(velocity.x)>15 and is_on_floor()
	var pose: String = "run" if running else "idle"
	var frame: int = int(_clock*7) if not running else int(_walk_clock*1.3)
	if not is_on_floor():
		pose = "jump"
		frame = 1 if velocity.y< -90 else 3 if velocity.y<90 else 5
	if _pulse_cooldown>0.19:
		pose = "shoot" if running else "stand"
		frame = int(_walk_clock*1.3) if running else 1
	if _attack_timer>0 or parry_time>0:
		pose = "stand"
		frame = maxi(0,_combo-1)
	if _knockback_timer>0:
		pose = "hurt"
		frame = 0
	var tilt: float = -0.13 if _dash_time>0 else 0
	var attack_lift: float = -1 if _attack_timer>0 and _combo==3 else 0
	draw_set_transform(Vector2(0,attack_lift),tilt*facing,Vector2(float(facing),1))
	# The courier's ember carrier and long scarf carry the same visual identity as the title.
	var wave: float = roundf(sin(_clock*9)*2)
	var trail: float = 25 if running or _dash_time>0 else 15
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-30),Vector2(-trail,-31+wave),Vector2(-trail+5,-25+wave),Vector2(-6,-26)]),Color("b65e43"))
	draw_line(Vector2(-trail+2,-30+wave),Vector2(-6,-29),Color("ffb26e"),1)
	COURIER.draw_pose(self,pose,frame)
	draw_rect(Rect2(-9,-27,4,11),Color("3d4242"))
	draw_rect(Rect2(-8,-25,2,6),Color("ffbc72"))
	if _attack_timer>0:
		_draw_slash()
	else:
		draw_line(Vector2(4,-17),Vector2(16,-2),Color("152432"),4)
		draw_line(Vector2(5,-17),Vector2(17,-2),Color("b7e3d5"),2)
		draw_line(Vector2(6,-17),Vector2(18,-2),CYAN,1)
		draw_line(Vector2(2,-14),Vector2(8,-19),Color("d5ae72"),2)
	draw_set_transform(Vector2.ZERO)
	if parry_time>0:
		var center: Vector2 = Vector2(facing*5,-19)
		draw_arc(center,26,-1.4 if facing>0 else 1.74,1.4 if facing>0 else 4.54,20,Color(CYAN,0.28),5)
		draw_arc(center,29,-1.3 if facing>0 else 1.84,1.3 if facing>0 else 4.44,20,LIGHT,2)

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-10,-1,20,2),Color(0.02,0.04,0.08,0.35))


func _draw_slash() -> void:
	var progress: float = 1.0 - _attack_timer / _attack_duration
	var radius: float = 46.0 if _combo == 3 else 38.0
	var reverse: bool = _combo == 2
	var angle: float = lerpf(-1.5, 1.45, progress)
	if reverse:
		angle = -angle
	var center: Vector2 = Vector2(3.0, -18.0)
	var arc_points: PackedVector2Array = PackedVector2Array()
	var inner_points: PackedVector2Array = PackedVector2Array()
	var sweep: float = 1.2
	for i: int in range(9):
		var theta: float = angle - float(i) / 8.0 * sweep * (-1.0 if reverse else 1.0)
		arc_points.append((center + Vector2(cos(theta), sin(theta)) * radius).round())
		inner_points.append((center + Vector2(cos(theta), sin(theta)) * (radius - 7.0)).round())
	var polygon: PackedVector2Array = arc_points.duplicate()
	inner_points.reverse()
	polygon.append_array(inner_points)
	draw_colored_polygon(polygon, Color(CYAN if _combo < 3 else EMBER, 0.6))
	draw_polyline(arc_points, LIGHT if _combo < 3 else Color("ffe5a1"), 2.0, false)
	var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 3.0)
	draw_line(center, tip.round(), IVORY, 3.0, false)
	draw_line(center, tip.round(), LIGHT, 1.0, false)
