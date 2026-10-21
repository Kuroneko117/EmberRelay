extends RefCounted
## One objective source for the HUD, map, gate hints and world markers.
var game: Node

func devices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game.chapter==3:
		out.append({"pos":Vector2(490,300),"on":game.presentation.circuit_on,"label":"入口供电","detail":"船坞入口地面 · 控制箱旁按 E","id":"P"})
	elif game.chapter==4:
		for i: int in range(game.presentation.relays.size()):
			var relay: Dictionary = game.presentation.relays[i]
			out.append({"pos":relay.pos,"on":relay.on,"label":"旧站台信标" if i==0 else "天线台信标",
				"detail":"沿台阶跳上旧站台 · 按 E 校准" if i==0 else "沿右侧台阶二段跳至天线台 · 按 E 校准","id":str(i+1)})
	return out

func relay_count() -> int:
	var count: int = 0
	for device: Dictionary in devices():
		if device.on: count += 1
	return count

func current() -> Dictionary:
	if not is_instance_valid(game.player): return {}
	if game.campaign.is_boss_sector():
		if game.boss_defeated: return _target("gate","投递火种",Vector2(game.portal_x,300),"终点门旁按 E · 完成本段航线")
		if game.boss_awake: return _target("combat","击败"+game.campaign.BOSSES[game.chapter/3],game.campaign.boss_home(),"避开预警 · 在守卫恢复时反击")
		return _target("boss","进入守卫区域",Vector2(game.campaign.arena_start()+30,300),"继续向右进入竞技场 · 无需寻找开关")
	var closest: Dictionary = {}
	var distance: float = INF
	for device: Dictionary in devices():
		if device.on: continue
		var value: float = game.player.position.distance_to(device.pos)
		if value<distance:
			distance = value
			closest = device
	if not closest.is_empty():
		var result: Dictionary = _target("device",closest.label,closest.pos,closest.detail)
		result.id = closest.id
		return result
	return _target("gate","前往"+("风暴之眼" if game.chapter==4 else game.chapter_names[game.chapter+1]),Vector2(game.portal_x,300),"右侧中继门旁按 E · 前往下一区域")

func _target(kind: String,title: String,pos: Vector2,detail: String) -> Dictionary:
	return {"kind":kind,"title":title,"pos":pos,"detail":detail}

func platform_route(from: Vector2,to: Vector2) -> Array[Vector2]:
	var start: int = _nearest_platform(from)
	var finish: int = _nearest_platform(to)
	if start<0 or finish<0: return []
	var parents: Dictionary = {start:-1}
	var queue: Array[int] = [start]
	while not queue.is_empty() and not parents.has(finish):
		var a: int = queue.pop_front()
		var platform: Rect2 = game.platforms[a]
		for b: int in range(game.platforms.size()):
			if parents.has(b): continue
			var next: Rect2 = game.platforms[b]
			var rise: float = platform.position.y-next.position.y
			var gap: float = maxf(0,maxf(next.position.x-platform.end.x,platform.position.x-next.end.x))
			if rise>108 or rise< -180 or gap>190-maxf(0,rise)*0.35: continue
			parents[b] = a
			queue.append(b)
	if not parents.has(finish): return []
	var indices: Array[int] = [finish]
	while indices[0]!=start: indices.push_front(parents[indices[0]])
	var route: Array[Vector2] = [from]
	for i: int in range(indices.size()-1):
		var a: Rect2 = game.platforms[indices[i]]
		var b: Rect2 = game.platforms[indices[i+1]]
		var x_a: float
		var x_b: float
		if b.position.x>=a.end.x:
			x_a = a.end.x-10
			x_b = b.position.x+10
		elif a.position.x>=b.end.x:
			x_a = a.position.x+10
			x_b = b.end.x-10
		else:
			x_a = clampf(to.x,maxf(a.position.x,b.position.x)+10,minf(a.end.x,b.end.x)-10)
			x_b = x_a
		var takeoff: Vector2 = Vector2(x_a,a.position.y)
		var landing: Vector2 = Vector2(x_b,b.position.y)
		route.append(takeoff)
		route.append(takeoff.lerp(landing,0.5)-Vector2(0,20))
		route.append(landing)
	route.append(to)
	return route

func _nearest_platform(pos: Vector2) -> int:
	var result: int = -1
	var best: float = INF
	for i: int in range(game.platforms.size()):
		var platform: Rect2 = game.platforms[i]
		var gap: float = maxf(0,maxf(platform.position.x-pos.x,pos.x-platform.end.x))
		var distance: float = gap+absf(platform.position.y-pos.y)*2
		if distance<best: best = distance; result = i
	return result

func direction(target: Dictionary) -> String:
	if target.is_empty() or target.kind=="combat": return "观察预警 · 伺机反击"
	var offset: Vector2 = target.pos-game.player.position
	if offset.length()<55:
		if target.kind=="device": return "E  "+("启动供电" if game.chapter==3 else "校准信标")
		if target.kind=="gate": return "E  进入中继门"
		return "继续向前 · 清除守卫" if target.kind=="seal" else "继续向右 · 进入守卫区"
	var arrow: String = "↑" if absf(offset.x)<45 and offset.y< -40 else "←" if offset.x<0 else "→"
	var height_hint: String = " · 上层" if offset.y< -45 else " · 地面" if target.kind=="device" else ""
	return "%s  %d m%s   ·   C 地图"%[arrow,ceili(offset.length()/16.0),height_hint]

func gate_hint() -> String:
	var target: Dictionary = current()
	if target.is_empty(): return "沿主路继续前进"
	if game.campaign.is_boss_sector() and not game.boss_defeated:
		return "终点仍被守卫锁定 · 先击败"+game.campaign.BOSSES[game.chapter/3]+"。\n观察预警，在恢复期反击。"
	if target.kind=="device":
		if game.chapter==3: return "中继门未供电 · P 号开关在船坞入口地面。\n按 C 查看位置，靠近控制箱按 E。"
		return "信标仅接通 %d/2 · 还需校准%s。\n按 C 查看位置，跳上标记平台后按 E。"%[relay_count(),target.title]
	if target.kind=="combat": return "观察预警，必要时可以退回中继站调整装配。"
	return target.detail
