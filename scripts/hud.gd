extends Node2D

const COURIER = preload("res://scripts/courier_art.gd")
const ART = preload("res://scripts/art.gd")
const FONT = preload("res://assets/ui_font.ttc")
const PALETTE = preload("res://scripts/visual_palette.gd")
const CREAM = PALETTE.PAPER
const AMBER = PALETTE.GOLD
const TEAL = PALETTE.SIGNAL
const MUTED = PALETTE.LIGHT
const DARK = PALETTE.DEEP
var game: Node


func _draw() -> void:
	if not is_instance_valid(game): return
	if game.state=="menu": _menu()
	if game.damage_flash>0 and game.state=="playing":
		draw_rect(Rect2(0,0,640,360),Color(0.9,0.3,0.22,game.damage_flash*0.28))
		draw_rect(Rect2(0,0,640,360),Color(0.9,0.3,0.22,game.damage_flash),false,3)
	if game.transition_alpha>0:
		draw_rect(Rect2(0,0,640,360),Color(0.07,0.12,0.16,game.transition_alpha))

func _text(value: String, pos: Vector2, size: int=12, color: Color=CREAM) -> void:
	draw_string(FONT,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _center(value: String, y: float, size: int=12, color: Color=CREAM, x: float=320) -> void:
	var width: float = FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_text(value,Vector2(x-width*0.5,y),size,color)

func _tracked(value: String, pos: Vector2, size: int, color: Color, spacing: float=3.0) -> void:
	var x: float = pos.x
	for character: String in value:
		_text(character,Vector2(x,pos.y),size,color)
		x += FONT.get_string_size(character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x+spacing

func _panel(rect: Rect2) -> void:
	var p: Vector2 = rect.position
	var e: Vector2 = rect.end
	var points: PackedVector2Array = PackedVector2Array([p+Vector2(8,0),Vector2(e.x-8,p.y),Vector2(e.x,p.y+8),e-Vector2(0,8),e-Vector2(8,0),Vector2(p.x+8,e.y),Vector2(p.x,e.y-8),p+Vector2(0,8)])
	draw_colored_polygon(points,Color("142731"))
	var edge: PackedVector2Array = points.duplicate()
	edge.append(points[0])
	draw_polyline(edge,Color("4a6670"),1)
	draw_rect(rect.grow(-4),Color("263f48"),false,1)
	draw_line(p+Vector2(12,0),p+Vector2(69,0),AMBER,2)
	for x: float in [p.x+10,e.x-11]:
		for y: float in [p.y+10,e.y-11]: draw_rect(Rect2(x,y,2,2),Color("728980"))

func _overlay() -> void:
	draw_rect(Rect2(0,0,640,360),Color(0.04,0.08,0.12,0.82))

func _flame(pos: Vector2, scale_value: float=1.0, color: Color=AMBER) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(1,-9),Vector2(-5,-2),Vector2(-5,4),Vector2(-1,7),Vector2(4,6),Vector2(7,1),Vector2(6,-5),Vector2(3,-1)])
	for i: int in range(points.size()):
		points[i] = pos+points[i]*scale_value
	draw_colored_polygon(points,color)
	draw_rect(Rect2(pos+Vector2(-1,0)*scale_value,Vector2(3,4)*scale_value),CREAM)

func _menu() -> void:
	# An illustrated diorama: the live city, the courier, a warm horizon and quiet ash.
	for i: int in range(32):
		draw_rect(Rect2(i*11,0,11,360),Color(0.035,0.07,0.1,0.98-float(i)*0.024))
	draw_rect(Rect2(0,331,640,29),Color(0.035,0.07,0.1,0.93))
	# Foreground girder and hand-painted pixels frame the character at four times game scale.
	ART.tile_strip(self,Rect2(0,128,64,16),Vector2(351,306),289,33,Color("b1aa95"))
	ART.tile_strip(self,Rect2(288,0,64,16),Vector2(342,335),298,28,Color("7a837f"))
	var bob: float = sin(game.clock*1.8)*0.8
	var hero: Vector2 = Vector2(464,306+bob)
	draw_set_transform(hero,0,Vector2(3.0,3.0))
	COURIER.draw_pose(self,"idle",int(game.clock*5))
	draw_set_transform(Vector2.ZERO)
	# A broken signal tower suggests the destination before the journey begins.
	ART.stamp(self,Rect2(272,0,16,64),Rect2(577,146,15,160),Color("afafa1"))
	draw_circle(Vector2(585,154),21,Color(0.8,0.57,0.3,0.07))
	draw_rect(Rect2(580,149,9,12),AMBER)
	draw_rect(Rect2(582,151,4,8),CREAM)

func _help() -> void:
	_overlay()
	_panel(Rect2(89,39,462,294))
	_center("信使手册",75,23)
	_center("解除封锁、探索补给箱，把火种带回灯塔。",99,11,MUTED)
	var rows: Array[Array] = [
		["A / D  或  ← / →","移动","SPACE / W / ↑","跳跃 · 可二段跳"],
		["长按 J / 左键","自动三连斩","K / 右键","能量波 · 辅助瞄准"],
		["SHIFT / L","无敌冲刺","E","机关 / 中继门 / 补给"],
		["Q / F","弹反 / 修复剂","R / TAB","余烬爆发 / 地图"],
		["S + SPACE","穿过薄平台向下跳","ESC / F11","暂停 / 全屏"]]
	for i: int in range(rows.size()):
		var y: float = 123+i*27
		_text(rows[i][0],Vector2(110,y),10,TEAL)
		_text(rows[i][1],Vector2(110,y+14),10,CREAM)
		_text(rows[i][2],Vector2(332,y),10,TEAL)
		_text(rows[i][3],Vector2(332,y+14),10,CREAM)
	draw_line(Vector2(110,256),Vector2(531,256),Color("3b5156"),1)
	_center("击碎货箱获得余烬。E 启动机关、阅读留言、进入工坊。",275,10,MUTED)

func _gameplay() -> void:
	if not is_instance_valid(game.player): return
	var p: Node = game.player
	# Compact status plate, separate from contextual actions and story captions.
	draw_rect(Rect2(12,12,198,44),Color(0.035,0.075,0.11,0.86))
	draw_rect(Rect2(12,12,2,44),AMBER)
	draw_set_transform(Vector2(33,51),0,Vector2(0.78,0.78))
	COURIER.draw_pose(self,"idle",0)
	draw_set_transform(Vector2.ZERO)
	_text("信使 07",Vector2(53,23),8,MUTED)
	for i: int in range(p.max_health):
		var x: float = 54+i*12
		draw_colored_polygon(PackedVector2Array([Vector2(x+2,28),Vector2(x+10,28),Vector2(x+8,34),Vector2(x,34)]),AMBER if i<p.health else Color("3a454b"))
	_text("能量",Vector2(53,47),7,MUTED)
	draw_rect(Rect2(75,42,117,3),Color("32474d"))
	draw_rect(Rect2(75,42,117*p.energy/100,3),TEAL)
	_text("%02d"%game.embers,Vector2(231,28),15,AMBER)
	_flame(Vector2(220,22),0.5)
	_text("记忆 %d / 18"%game.relics,Vector2(219,44),8,MUTED)
	_text(game.format_time(game.elapsed),Vector2(296,28),10,MUTED)
	draw_line(Vector2(296,42),Vector2(401,42),Color("3c5057"),2)
	var progress: float = clampf(p.position.x/game.level_width,0,1)
	draw_line(Vector2(296,42),Vector2(296+progress*105,42),AMBER,2)
	draw_circle(Vector2(296+progress*105,42),2,CREAM)
	draw_rect(Rect2(425,12,203,44),Color(0.035,0.075,0.11,0.80))
	_text("%02d"%(game.chapter/3+1),Vector2(438,31),16,AMBER)
	_text(game.chapter_names[game.chapter],Vector2(466,28),11)
	var objective: String = "前往中继门  →" if game.gate_open() else "校准信标 / 解除封锁" if game.chapter==4 and not game.presentation.circuit_on else "恢复船坞供电" if game.chapter==3 and not game.presentation.circuit_on else "封锁  %d / %d"%[game.director.cleared,game.director.arenas.size()] if not game.campaign.is_boss_sector() else "击败"+game.campaign.BOSSES[game.chapter/3]
	_text(objective,Vector2(466,44),9,TEAL if game.gate_open() else MUTED)
	# Sparse quick slots reveal readiness through fill and colour.
	var slots: Array = [["Q","弹反",p.parry_cooldown<=0],["F","修复 ×%d"%game.director.potions,game.director.potions>0],["R","爆发",game.director.focus>=100],["SHIFT","冲刺",p.dash_cooldown<=0]]
	for i: int in range(slots.size()):
		var x: float = 13+i*43
		var col: Color = TEAL if slots[i][2] else MUTED.darkened(0.35)
		draw_rect(Rect2(x,314,37,31),Color(0.035,0.075,0.11,0.85))
		draw_rect(Rect2(x,314,37,1),col)
		_center(slots[i][0],325,7,col,x+18)
		_center(slots[i][1],339,8,col,x+18)
		if i==2:
			draw_rect(Rect2(x+3,344,31*game.director.focus/100,1),AMBER)
	_text("TAB 地图   ESC 暂停",Vector2(524,347),8,MUTED)
	if game.boss_awake and not game.boss_defeated and is_instance_valid(game.boss):
		var boss: Node = game.boss
		_center(game.campaign.BOSSES[game.chapter/3]+" / "+("核心过载" if boss.phase>=2 else "守护协议"),79,10,AMBER)
		draw_rect(Rect2(190,87,260,4),Color("403139"))
		draw_rect(Rect2(190,87,260*float(boss.health)/boss.max_health,4),Color("e9a177"))
		for i: int in range(1,10): draw_line(Vector2(190+i*26,87),Vector2(190+i*26,91),Color("302832"),1)
	if game.presentation.sector_title>0 and not game.boss_awake:
		var a: float = minf(1,game.presentation.sector_title)
		draw_rect(Rect2(18,211,2,64),Color(AMBER,a))
		_text("CHAPTER %02d / 区域 %02d"%[game.chapter/3+1,game.chapter%3+1],Vector2(28,225),8,Color(TEAL,a))
		_text(game.chapter_names[game.chapter],Vector2(26,252),24,Color(CREAM,a))
		_text(game.chapter_codes[game.chapter],Vector2(28,270),9,Color(MUTED,a))
	if game.notice_timer>0:
		var w: float = minf(604,FONT.get_string_size(game.notice,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+24)
		draw_rect(Rect2(320-w/2,285,w,22),Color(0.035,0.075,0.11,0.93))
		_center(game.notice,300,10,CREAM)
	elif game.chapter==0 and p.position.x<250 and game.presentation.sector_title<=0:
		draw_rect(Rect2(189,285,294,22),Color(0.035,0.075,0.11,0.9))
		_center("A / D 移动    SPACE 二段跳    J 连斩",300,10,CREAM,336)

func _upgrade() -> void:
	_overlay()
	_center("CHAPTER 01 / DELIVERED",48,10,TEAL)
	_center("北线航线，已经接通",82,26,CREAM)
	_center("选择一枚有限强化核心，前往苍穹水库。  /  1、2、3",106,11,MUTED)
	_center("下一章  ·  苍穹水库 / 风暴织机",328,11,AMBER)

func _upgrade_cards() -> void:
	var titles: Array[String] = ["锋 芒", "余 温", "回 响"]
	var subtitles: Array[String] = ["锐化旧世界的刀锋", "让火种护住你的心跳", "唤醒沉睡的能量核心"]
	var descriptions: Array[String] = ["近战伤害 +15% · 最多两级", "最大生命 +1 · 仅此一次", "能量波伤害 +12% · 最多两级"]
	for i: int in range(3):
		var x: float = 132+i*188
		_text("0%d" % (i+1),Vector2(x-72,148),9,MUTED)
		match i:
			0:
				draw_line(Vector2(x-12,191),Vector2(x+12,164),AMBER,4)
				draw_line(Vector2(x-17,185),Vector2(x-5,195),CREAM,3)
			1:
				_flame(Vector2(x,179),2,AMBER)
			2:
				draw_circle(Vector2(x,178),13,Color("2d555a"))
				draw_arc(Vector2(x,178),16,0.5,5.8,24,TEAL,2)
				draw_rect(Rect2(x-4,171,8,14),TEAL)
		_center(titles[i],221,19,CREAM,x)
		_center(subtitles[i],245,9,MUTED,x)
		_center(descriptions[i],270,11,TEAL,x)

func _victory() -> void:
	_overlay()
	_panel(Rect2(125,30,390,305))
	_flame(Vector2(320,64),1.5)
	_center("DELIVERY COMPLETE",99,10,TEAL)
	_center("今夜，仍有光。",137,29,CREAM)
	_center("旧世界的十八段记忆，终于找到了归宿。" if game.relics==18 else "你把最后的火种，交给了等待黎明的人。",165,11,MUTED)
	draw_line(Vector2(151,183),Vector2(489,183),Color("3b5156"),1)
	_center("旅途用时",205,9,MUTED,194)
	_center("记忆碎片",205,9,MUTED,320)
	_center("传递评分",205,9,MUTED,446)
	_center(game.format_time(game.elapsed),231,21,CREAM,194)
	_center("%d / 18" % game.relics,231,21,TEAL,320)
	_center(str(game.run_score),231,21,AMBER,446)
	_center("击败 %d 名看守    ·    重新点燃 %d 次    ·    最佳 %d" % [game.total_kills,game.deaths,game.best_score],260,9,MUTED)

func _button(button: Dictionary) -> void:
	var rect: Rect2 = button.rect
	if game.state=="world_map" and button.label.is_empty(): return
	var hover: bool = rect.has_point(get_local_mouse_position()) or (game.state!="playing" and game.get_buttons().find(button)==game.ui_focus)
	var primary: bool = button.primary
	var bg: Color = AMBER if primary else Color("1c3038")
	if hover: bg = bg.lightened(0.11)
	draw_rect(Rect2(rect.position+Vector2(0,3),rect.size),Color(0.02,0.07,0.1,0.3))
	draw_rect(rect,bg)
	draw_rect(rect,CREAM if hover else (AMBER if primary else Color("496164")),false,1)
	if game.state=="upgrade" and hover:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),AMBER)
	if button.label!="":
		_center(button.label,rect.position.y+rect.size.y/2+4,11 if rect.size.y>25 else 9,DARK if primary else CREAM,rect.get_center().x)
