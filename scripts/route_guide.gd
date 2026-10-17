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
	if game.director.active_arena>=0:
		return _target("combat","封锁 %d · 第 %d 波"%[game.director.active_arena+1,maxi(1,game.director.wave)],game.player.position,"清除本区守卫后继续探索")
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
	for i: int in range(game.director.arenas.size()):
		var arena: Dictionary = game.director.arenas[i]
		if not arena.done: return _target("seal","解除封锁 %d / %d"%[i+1,game.director.arenas.size()],Vector2(arena.left+65,300),"沿主路前进 · 清除封锁区守卫")
	return _target("gate","前往"+("风暴之眼" if game.chapter==4 else game.chapter_names[game.chapter+1]),Vector2(game.portal_x,300),"右侧中继门旁按 E · 前往下一区域")

func _target(kind: String,title: String,pos: Vector2,detail: String) -> Dictionary:
	return {"kind":kind,"title":title,"pos":pos,"detail":detail}

func direction(target: Dictionary) -> String:
	if target.is_empty() or target.kind=="combat": return "观察预警 · 伺机反击"
	var offset: Vector2 = target.pos-game.player.position
	if offset.length()<55: return "E  "+("启动供电" if game.chapter==3 and target.kind=="device" else "校准信标" if target.kind=="device" else "进入中继门" if target.kind=="gate" else "继续向右")
	var arrow: String = "↑" if absf(offset.x)<45 and offset.y< -40 else "←" if offset.x<0 else "→"
	var height_hint: String = " · 上层" if offset.y< -45 else " · 地面" if target.kind=="device" else ""
	return "%s  %d m%s   ·   C 地图"%[arrow,ceili(offset.length()/16.0),height_hint]

func gate_hint() -> String:
	var target: Dictionary = current()
	if target.is_empty(): return "沿主路继续前进"
	if target.kind=="device":
		if game.chapter==3: return "中继门未供电 · P 号开关在船坞入口地面。\n按 C 查看位置，靠近控制箱按 E。"
		return "信标仅接通 %d/2 · 还需校准%s。\n按 C 查看位置，跳上标记平台后按 E。"%[relay_count(),target.title]
	if target.kind=="seal" or target.kind=="combat": return "中继门等待解除封锁 %d / %d。按 C 查看当前目标。"%[game.director.cleared,game.director.arenas.size()]
	return target.detail
