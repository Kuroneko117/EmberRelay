extends Node2D
## Two major regions, persistent subareas and a traversable route atlas.
const FONT = preload("res://assets/ui_font.ttc")
const CREAM = Color("eee5cd")
const TEAL = Color("79d8cc")
const AMBER = Color("efb473")
var game: Node
var local_return: String = "world_map"
var unlocked: int = 0
signal selection_changed
var selected: int = 0:
	set(value):
		selected = value
		selection_changed.emit()
var completed: Array[int] = []
var visited: Array[int] = []
var sector_states: Dictionary = {}
var map_return: String = "menu"
var rest_points: Array[float] = []
var rewards: Array[int] = []
var atlas_time: float = 0
const REGIONS = ["北线余烬", "苍穹水库"]
const BOSSES = ["熔炉看守", "风暴织机"]
const DESCRIPTIONS = ["风蚀前哨 → 雨蚀管廊 → 最后的熔炉", "潮汐船坞 → 断弦高架 → 风暴之眼"]

func _process(delta: float) -> void:
	atlas_time += delta
	if game.state in ["world_map","journal"]: game.hud.queue_redraw()

func reset() -> void:
	unlocked = 1 if game.best_score>0 else 0
	selected = 0
	completed.clear()
	visited.clear()
	sector_states.clear()
	rewards.clear()
	map_return = "menu"

func is_boss_sector(sector: int=-1) -> bool:
	return (game.chapter if sector<0 else sector)%3==2

func arena_start() -> float:
	return 2820.0 if game.chapter==5 else 1490.0

func boss_home() -> Vector2:
	return Vector2(3320,239) if game.chapter==5 else Vector2(1850,290)

func checkpoints() -> Array:
	return [[1080.0],[1080.0],[1350.0],[665.0,2420.0],[680.0,2670.0],[650.0,2620.0]][game.chapter]

func sector_loaded() -> void:
	rest_points.clear()
	if not visited.has(game.chapter): visited.append(game.chapter)

func landmarks() -> Array:
	return [
		[{"x":330,"name":"废弃货站","kind":"depot"},{"x":1120,"name":"检修场","kind":"station"},{"x":2020,"name":"北线出口","kind":"station"}],
		[{"x":350,"name":"进水闸","kind":"pump"},{"x":1120,"name":"输水机组","kind":"conduit"},{"x":1810,"name":"泵房站台","kind":"pump"}],
		[{"x":470,"name":"炉前检修线","kind":"forge"},{"x":1270,"name":"整备平台","kind":"station"},{"x":1830,"name":"熔炉核心","kind":"forge"}],
		[{"x":360,"name":"入口起重架","kind":"crane"},{"x":1960,"name":"停泊货船","kind":"dock"},{"x":2780,"name":"北岸装卸台","kind":"crane"}],
		[{"x":380,"name":"高架入口","kind":"pylon"},{"x":1150,"name":"旧站台信标","kind":"signal"},{"x":2940,"name":"天线台信标","kind":"signal"}],
		[{"x":530,"name":"观测前站","kind":"signal"},{"x":2320,"name":"风暴观测台","kind":"signal"},{"x":3330,"name":"织机核心","kind":"storm"}]
	][game.chapter]

func extra_layout(sector: int) -> Dictionary:
	var data: Dictionary = {"width":3500.0,"platforms":[],"lamps":[],"enemies":[],"relics":[]}
	if sector==3:
		data.width = 3500.0
		data.platforms = [Rect2(-60,300,700,160),Rect2(735,300,735,160),Rect2(1570,300,710,160),Rect2(2390,300,660,160),Rect2(3140,300,420,160),
			Rect2(250,246,140,14),Rect2(440,201,130,14),Rect2(885,240,150,14),Rect2(1110,185,150,14),Rect2(1320,144,125,14),
			Rect2(1640,245,145,14),Rect2(1835,198,145,14),Rect2(2070,151,150,14),Rect2(2470,243,135,14),Rect2(2715,195,140,14),Rect2(2925,152,150,14),Rect2(3210,235,145,14)]
		data.enemies = [["guard",435,298],["sentry",1160,184],["drone",1450,180],["scout",2530,298],["sentry",2980,150],["guard",3290,298]]
		data.relics = [Vector2(500,170),Vector2(1380,112),Vector2(2980,120)]
	elif sector==4:
		data.width = 3780.0
		data.platforms = [Rect2(-60,300,680,160),Rect2(720,300,650,160),Rect2(1470,300,820,160),Rect2(2390,300,660,160),Rect2(3150,300,690,160),
			Rect2(230,247,130,14),Rect2(420,193,145,14),Rect2(840,242,145,14),Rect2(1060,213,170,14),Rect2(1260,157,150,14),
			Rect2(1550,244,140,14),Rect2(1770,189,150,14),Rect2(2010,139,170,14),Rect2(2470,245,150,14),Rect2(2680,205,150,14),Rect2(2870,168,160,14),Rect2(3260,234,145,14),Rect2(3480,182,145,14)]
		data.enemies = [["guard",455,298],["sentry",1110,212],["drone",1430,160],["sentry",2090,138],["drone",2880,135],["guard",3330,298],["sentry",3540,181]]
		data.relics = [Vector2(1330,125),Vector2(2090,107),Vector2(3550,150)]
	else:
		data.width = 3980.0
		data.platforms = [Rect2(-60,300,780,160),Rect2(825,300,785,160),Rect2(1710,300,790,160),Rect2(2600,300,1440,160),
			Rect2(260,244,145,14),Rect2(490,193,155,14),Rect2(930,243,150,14),Rect2(1170,190,155,14),Rect2(1420,146,145,14),
			Rect2(1830,244,145,14),Rect2(2050,191,155,14),Rect2(2290,145,150,14),Rect2(2730,244,120,14),Rect2(3070,247,125,14),Rect2(3500,247,125,14)]
		data.enemies = [["guard",440,298],["sentry",1210,189],["drone",1570,160],["guard",1950,298],["sentry",2340,144],["drone",2520,180]]
		data.relics = [Vector2(565,161),Vector2(1490,114),Vector2(2360,113)]
	for x: int in range(170,int(data.width),420): data.lamps.append(Vector2(x,300))
	return data

func connect_upper_routes() -> void:
	# Keep all old floors, checkpoints, items and saved positions intact.
	var links: Array = [[Rect2(625,226,115,14)],[Rect2(555,224,112,14),Rect2(1595,195,96,14)],[],
		[Rect2(615,222,120,14),Rect2(2295,216,112,14)],[Rect2(2820,239,100,14)],[]]
	for link: Rect2 in links[game.chapter]: game.platforms.append(link)

func capture_sector() -> Dictionary:
	if not is_instance_valid(game.player): return {}
	var foes: Array = []
	for e: Node in game.enemies:
		if is_instance_valid(e) and not e.dead: foes.append({"kind":e.kind,"pos":e.position,"hp":e.health})
	return {"enemies":foes,"pickups":game.pickups.duplicate(true),"arenas":game.director.arenas.duplicate(true),"chests":game.director.chests.duplicate(true),
		"cleared":game.director.cleared,"boss_defeated":game.boss_defeated,"rest":rest_points.duplicate(),"scenery":game.presentation.snapshot(),"checkpoint":game.checkpoint,"checkpoint_active":game.checkpoint_active,"checkpoint_x":game.checkpoint_x}

func restore_sector(data: Dictionary) -> void:
	if data.is_empty(): return
	for e: Node in game.enemies:
		if is_instance_valid(e): e.queue_free()
	game.enemies.clear()
	game.boss = null
	for saved: Dictionary in data.enemies:
		var foe: Node = game._spawn_enemy(saved.kind,saved.pos)
		foe.health = saved.hp
		if saved.kind in ["boss","tempest"]: game.boss = foe
	game.pickups.assign(data.pickups)
	game.director.arenas.assign(data.arenas)
	game.director.chests.assign(data.chests)
	game.director.cleared = data.cleared
	game.boss_defeated = data.boss_defeated
	rest_points.assign(data.rest)
	game.checkpoint = data.checkpoint
	game.checkpoint_active = data.checkpoint_active
	game.checkpoint_x = data.checkpoint_x
	game.presentation.restore(data.scenery)

func travel_to(destination: int, from_left: bool=true) -> void:
	if destination<0 or destination>5 or destination/3>unlocked: return
	if is_instance_valid(game.player) and (game.director.active_arena>=0 or (game.boss_awake and not game.boss_defeated)):
		game.show_notice("封锁解除后才能离开这片区域")
		return
	var hp: int = game.player.health if is_instance_valid(game.player) else 6+game.bonus_health
	var charges: int = game.director.potions
	if is_instance_valid(game.player): sector_states[game.chapter] = capture_sector()
	game.chapter = destination
	game._load_chapter()
	if sector_states.has(destination): restore_sector(sector_states[destination])
	game.player.position = Vector2(75,294) if from_left else Vector2(game.portal_x-75,294)
	game.player.health = mini(game.player.max_health,maxi(1,hp))
	game.director.potions = mini(2,charges)
	game.safe_position = game.player.position
	game.player.invulnerable = 1.2
	game.camera.position.x = clampf(game.player.position.x,320,game.level_width-320)
	game.director.save_campaign()

func open_map() -> void:
	map_return = game.state
	selected = mini(unlocked,game.chapter/3) if is_instance_valid(game.player) else 0
	game.state = "world_map"
	game.ui_focus = 0

func finish_region(choice: int) -> void:
	var region: int = game.chapter/3
	if not rewards.has(region):
		rewards.append(region)
		match choice:
			0: game.damage_bonus = mini(2,game.damage_bonus+1)
			1: game.bonus_health = mini(1,game.bonus_health+1)
			2: game.pulse_bonus = mini(2,game.pulse_bonus+1)
	if not completed.has(region): completed.append(region)
	unlocked = 1
	sector_states[game.chapter] = capture_sector()
	selected = mini(1,region+1)
	game.state = "world_map"
	map_return = "playing"
	game.director.save_campaign()

func snapshot() -> Dictionary:
	return {"unlocked":unlocked,"completed":completed.duplicate(),"visited":visited.duplicate(),"sectors":sector_states.duplicate(true),"rewards":rewards.duplicate(),"rest":rest_points.duplicate()}

func restore(data: Dictionary) -> void:
	unlocked = maxi(1 if game.best_score>0 else 0,int(data.get("unlocked",0)))
	completed.assign(data.get("completed",[]))
	visited.assign(data.get("visited",[game.chapter]))
	sector_states = data.get("sectors",{}).duplicate(true)
	rewards.assign(data.get("rewards",[]))
	rest_points.assign(data.get("rest",[]))

func action(value: String) -> void:
	match value:
		"atlas": open_map()
		"atlas_back": game.state = map_return if map_return!="world_map" else "menu"
		"region0": selected = 0
		"region1": selected = 1
		"depart":
			if selected>unlocked:
				game.show_notice("击败熔炉看守后，苍穹航线才会开放")
				return
			var destination: int = selected*3
			if is_instance_valid(game.player) and game.chapter/3==selected and not game.boss_defeated: destination = game.chapter
			travel_to(destination)
		"local_map":
			local_return = game.state
			game.state = "journal"
		"local_back": game.state = local_return
	if value.begins_with("route_"):
		var destination: int = int(value.trim_prefix("route_"))
		if visited.has(destination) or (destination%3==0 and destination/3<=unlocked): travel_to(destination)

func buttons() -> Array[Dictionary]:
	if game.state=="world_map":
		var out: Array[Dictionary] = [game.director.button(Rect2(28,78,174,69),"","region0"),game.director.button(Rect2(28,157,174,69),"","region1"),
			game.director.button(Rect2(415,294,194,34),"前往航线    →" if selected<=unlocked else "航线尚未接通","depart",selected<=unlocked),
			game.director.button(Rect2(28,298,90,29),"返回","atlas_back")]
		if is_instance_valid(game.player): out.append(game.director.button(Rect2(123,298,79,29),"区域图","local_map"))
		var nodes: Array[Vector2] = [Vector2(278,187),Vector2(408,146),Vector2(553,207)]
		for i: int in range(3):
			var destination: int = selected*3+i
			if visited.has(destination): out.append(game.director.button(Rect2(nodes[i]-Vector2(18,18),Vector2(36,36)),"","route_"+str(destination)))
		return out
	if game.state=="journal": return [game.director.button(Rect2(239,298,162,29),"返回世界地图","local_back",true)]
	return []

func draw_atlas(h: Node2D) -> void:
	h.draw_rect(Rect2(0,0,640,360),Color("0d1924"))
	for i: int in range(22):
		var x: float = i*37
		h.draw_polyline(PackedVector2Array([Vector2(x-80,65),Vector2(x+25,122),Vector2(x-12,197),Vector2(x+83,300),Vector2(x+110,360)]),Color(0.24,0.37,0.4,0.12),1)
	h._text("THE LONG ROAD  /  航线总览",Vector2(29,33),10,TEAL)
	h._text("让火种抵达更远的地方",Vector2(29,57),19)
	h.draw_line(Vector2(218,78),Vector2(218,328),Color("3a535d"),1)
	for r: int in range(2):
		var y: float = 78+r*79
		h.draw_rect(Rect2(28,y,174,69),Color("233b44") if selected==r else Color("142730"))
		h.draw_rect(Rect2(28,y,3,69),AMBER if selected==r else Color("48636b"))
		h._text("CHAPTER %02d"%(r+1),Vector2(40,y+16),8,TEAL if r<=unlocked else Color("697d83"))
		h._text(REGIONS[r],Vector2(40,y+39),19,CREAM if r<=unlocked else Color("697d83"))
		h._text("已送达" if completed.has(r) else "航线开放" if r<=unlocked else "等待首领信号",Vector2(40,y+57),9,AMBER if r<=unlocked else Color("697d83"))
	h._text("%02d / %02d 首领已击败"%[completed.size(),2],Vector2(30,251),10,TEAL)
	h._text("区域探索 %d / 6"%visited.size(),Vector2(30,270),10,Color("9aaeb0"))
	var colour: Color = Color("c18e69") if selected==0 else TEAL
	# Coast lines, bridges, station clusters and contour marks build a cartographic world.
	for j: int in range(4):
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(15): pts.append(Vector2(240+i*27,103+j*35+sin(i*0.8+j)*14))
		h.draw_polyline(pts,Color(colour,0.10),2)
	var nodes: Array[Vector2] = [Vector2(278,187),Vector2(408,146),Vector2(553,207)]
	for i: int in range(2):
		h.draw_line(nodes[i],nodes[i+1],Color("415b62"),6)
		h.draw_line(nodes[i],nodes[i+1],Color(colour,0.8),1)
	for i: int in range(3):
		var sector: int = selected*3+i
		var p: Vector2 = nodes[i]
		for j: int in range(5):
			var x: float = p.x-26+j*11
			var height: float = 12+posmod(j*13+i*7,26)
			h.draw_rect(Rect2(x,p.y-height-16,8,height),Color("314651"))
		var unlocked_node: bool = visited.has(sector) or (i==0 and selected<=unlocked)
		h.draw_circle(p,14,Color("142831"))
		h.draw_arc(p,15,0,TAU,32,colour if unlocked_node else Color("48606a"),2)
		if i==2:
			h._flame(p,0.85,AMBER if selected<=unlocked else Color("6f7d7d"))
		else: h.draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),colour if unlocked_node else Color("48606a"))
		if is_instance_valid(game.player) and game.chapter==sector:
			h.draw_arc(p,21+sin(atlas_time*3)*2,0,TAU,32,Color(TEAL,0.6),1)
			h._center("你在这里",p.y+43,9,TEAL,p.x)
		h._center(game.chapter_names[sector],p.y+30,10,CREAM,p.x)
	h._text("终点首领 / "+BOSSES[selected],Vector2(244,275),11,AMBER)
	h._text("1 / 2 选择章节 · ENTER 出发 · 点击已探索节点可返回",Vector2(244,345),8,Color("8fa9ab"))
	if game.best_score>0 and not completed.has(0): h._text("旧版通关记录已识别，第二章可直接进入",Vector2(243,92),9,TEAL)
	if game.notice_timer>0: h._text(game.notice,Vector2(244,292),8,AMBER)
