extends Node2D
## World-space raster feedback. Gameplay owns contacts; this node only renders them.
var game: Node
var actors: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var age: float = 0
var textures: Dictionary = {}
const DATA = {"slash":[Vector2(96,96),Vector2(48,64),6,0.12],"muzzle":[Vector2(32,32),Vector2(8,16),4,0.12],"pulse":[Vector2(32,16),Vector2(24,8),4,0.16],"impact":[Vector2(32,32),Vector2(16,16),5,0.15]}
func _ready() -> void:
	z_index = 16
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key: String in DATA:
		var path: String = "res://assets/studio/combat/"+key+".png"
		if ResourceLoader.exists(path): textures[key] = load(path)
func clear_actor() -> void:
	actors.clear(); queue_redraw()
func clear_all() -> void:
	actors.clear(); contacts.clear(); queue_redraw()
func slash(pos: Vector2,direction: int,combo: int) -> void:
	actors.append({"kind":"slash","pos":pos,"dir":direction,"combo":combo,"time":0.0,"follow":true})
func muzzle(pos: Vector2,direction: int) -> void:
	actors.append({"kind":"muzzle","pos":pos,"dir":direction,"combo":0,"time":0.0,"follow":pos.distance_to(game.player.pulse_muzzle())<1})
func impact(pos: Vector2) -> void:
	contacts.append({"pos":pos,"time":0.0})
func _process(delta: float) -> void:
	if game.state!="playing":
		if game.state!="paused": clear_all()
		queue_redraw()
		return
	if game.hit_pause<=0:
		age += delta
		for list: Array in [actors,contacts]:
			for index: int in range(list.size()-1,-1,-1):
				var item: Dictionary = list[index]
				item.time += delta
				if item.time>=float(DATA[item.get("kind","impact")][3]): list.remove_at(index)
	queue_redraw()
func stamp(kind: String,pos: Vector2,frame: int,direction: int=1,angle: float=0) -> void:
	if not textures.has(kind): return # Assets must be delivered; no geometric stand-in.
	var d: Array = DATA[kind]
	draw_set_transform(pos.round(),angle*direction,Vector2(direction,1))
	var pivot: Vector2 = Vector2(48,48) if kind=="slash" else d[1]
	draw_texture_rect_region(textures[kind],Rect2(-pivot,d[0]),Rect2(Vector2(frame*d[0].x,0),d[0]))
	draw_set_transform(Vector2.ZERO)
func _draw() -> void:
	if game.state!="playing" or not is_instance_valid(game.player): return
	for item: Dictionary in actors:
		if item.kind=="slash" and (game.player._attack_timer<=0 or game.player.dead): continue
		if item.kind=="muzzle" and game.player._pulse_pose_time<=0: continue
		var pos: Vector2 = item.pos
		if item.follow: pos = game.player.pulse_muzzle() if item.kind=="muzzle" else game.player.global_position
		var frame: int = mini(int(item.time/float(DATA[item.kind][3])*int(DATA[item.kind][2])),int(DATA[item.kind][2])-1)
		var angle: float = 0
		if item.kind=="slash":
			pos += Vector2(item.dir*12,-30) # Rotate around upper-body/hand, never around feet.
			if item.combo==2: angle = -0.55
			elif item.combo==3: angle = 0.65
		stamp(item.kind,pos,frame,item.dir,angle)
	for shot: Dictionary in game.projectiles:
		if shot.hostile: continue
		stamp("pulse",shot.pos,int(age/0.04)%4,1,shot.vel.angle())
	for item: Dictionary in contacts:
		stamp("impact",item.pos,mini(4,int(item.time/0.03)))
