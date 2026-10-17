extends Control
const UNITS = preload("res://scripts/enemy_visual.gd")
var family: String = "scout"
var sprite: AnimatedSprite2D
var pods: Array[AnimatedSprite2D] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = UNITS.frames_for(family)
	sprite.offset = Vector2(0,-24)
	sprite.play("idle")
	add_child(sprite)
	if family=="tempest":
		for i: int in range(4):
			var pod: AnimatedSprite2D = AnimatedSprite2D.new()
			pod.sprite_frames = UNITS.frames_for("drone")
			pod.offset = Vector2(0,-24)
			pod.scale = Vector2.ONE*0.32
			pod.play("move")
			add_child(pod)
			pods.append(pod)
	resized.connect(_layout)
	_layout()
func _layout() -> void:
	if not is_instance_valid(sprite): return
	sprite.position = Vector2(size.x/2,size.y-2)
	var factor: float = minf(size.x/80.0,size.y/60.0)
	if family!="boss": factor *= 1.55
	sprite.scale = Vector2.ONE*factor
	for i: int in range(pods.size()): pods[i].position = Vector2(size.x/2,size.y-19)+Vector2.from_angle(i*TAU/4)*Vector2(27,18)
