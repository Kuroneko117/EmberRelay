extends AnimatedSprite2D
## Licensed animation strips. Gameplay owns timings; the visual follows those timings.
static var library: Dictionary = {}
var unit: Node
var family: String
var dying: bool = false
var shot_left: float = 0
var shot_duration: float = 0.3

static func frames_for(which: String) -> SpriteFrames:
	if library.has(which): return library[which]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var names: Array[String] = ["idle","move","attack","warning","hurt","death"]
	if which=="boss": names.append_array(["shot","rise","fall"])
	for clip: String in names:
		var texture: Texture2D = load("res://assets/art/units/%s-%s.png"%[which,clip])
		frames.add_animation(clip)
		frames.set_animation_loop(clip,clip not in ["death","hurt"])
		frames.set_animation_speed(clip,12 if clip in ["attack","death","move"] else 7)
		for index: int in range(texture.get_width()/80):
			if which=="boss" and clip=="warning" and index%2==0: continue
			var tile: AtlasTexture = AtlasTexture.new()
			tile.atlas = texture
			tile.region = Rect2(index*80,0,80,80)
			frames.add_frame(clip,tile)
	library[which] = frames
	return frames

func configure(owner_unit: Node,which: String) -> void:
	unit = owner_unit
	family = which
	sprite_frames = frames_for(which)
	offset = Vector2(0,-24)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sizes: Dictionary = {"scout":1.2,"guard":1.45,"sentry":1.25,"drone":1.0,"boss":1.25,"tempest":1.85}
	scale = Vector2.ONE*float(sizes[which])
	animation_finished.connect(_finished)
	play("idle")

func show_attack(duration: float=0.3) -> void:
	shot_duration = duration
	shot_left = duration

func _process(_delta: float) -> void:
	if not is_instance_valid(unit): return
	flip_h = unit.facing<0
	if unit.dead:
		if not dying:
			dying = true
			modulate = Color.WHITE
			speed_scale = 1
			play("death")
		return
	if unit.game.state!="playing" or unit.game.hit_pause>0:
		speed_scale = 0
		return
	speed_scale = 1
	shot_left = maxf(0,shot_left-_delta)
	modulate = Color(1.6,1.4,1.16) if unit.flash>0 else Color.WHITE
	var clip: String = "move" if absf(unit.velocity.x)>5 else "idle"
	var progress: float = -1
	if unit.mode=="warning":
		clip = "warning"
		progress = 1-clampf(unit.timer/maxf(0.01,unit.warning_time),0,1)
		if family=="boss" and unit.attack_kind=="slam":
			clip = "attack"
			progress *= 0.38
	elif unit.mode=="active":
		clip = "attack"
		if family in ["scout","guard"]: progress = 1-clampf(unit.timer/(0.28 if family=="scout" else 0.2),0,1)
		if family=="boss":
			if unit.attack_kind=="rush": clip = "move"
			elif unit.attack_kind=="fan": clip = "shot"
			elif unit.attack_kind=="slam": progress = 0.38+(1-clampf(unit.timer/0.22,0,1))*0.62
	elif unit.stun>0 and unit.mode!="recovery": clip = "hurt"
	if family=="tempest" and unit.mode=="idle": clip = "move"
	if shot_left>0:
		clip = "shot" if family=="boss" else "attack"
		progress = 1-shot_left/shot_duration
	if animation!=clip: play(clip)
	if progress>=0:
		pause()
		frame = clampi(int(progress*(sprite_frames.get_frame_count(clip)-1)),0,sprite_frames.get_frame_count(clip)-1)
	elif not is_playing(): play()

func _finished() -> void:
	if dying and is_instance_valid(unit): unit.queue_free()
