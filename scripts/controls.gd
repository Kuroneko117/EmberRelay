extends Node
## Device bindings, conflict-safe keyboard remapping and prompt ownership.
signal changed
const ACTIONS = ["move_left","move_right","jump","attack","pulse","dash","parry","heal","burst","interact","local_map","journal"]
const LABELS = ["左移","右移","跳跃","近战","射击","冲刺","弹反","修复","爆发","交互","区域图","航线图"]
const PAD_NAMES = {"move_left":"左摇杆 ←","move_right":"左摇杆 →","jump":"A","attack":"X","pulse":"Y","dash":"B","parry":"LB","heal":"LT","burst":"RT","interact":"RB","pause_game":"START","local_map":"RS","journal":"BACK"}
var game: Node
var pad_active: bool = false
var lessons_enabled: bool = true
var capture_action: String = ""
var status: String = "选择一项后，按下新的键盘按键。Esc 取消。"
var defaults: Dictionary = {}

func setup() -> void:
	for action: String in ACTIONS: defaults[action] = InputMap.action_get_events(action).duplicate()
	var buttons: Dictionary = {"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"pulse":JOY_BUTTON_Y,"dash":JOY_BUTTON_B,"parry":JOY_BUTTON_LEFT_SHOULDER,"interact":JOY_BUTTON_RIGHT_SHOULDER,"pause_game":JOY_BUTTON_START,"journal":JOY_BUTTON_BACK,"local_map":JOY_BUTTON_RIGHT_STICK,"move_left":JOY_BUTTON_DPAD_LEFT,"move_right":JOY_BUTTON_DPAD_RIGHT,"down":JOY_BUTTON_DPAD_DOWN}
	for action: String in buttons:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action,event)
	var menu_buttons: Dictionary = {"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN}
	for action: String in menu_buttons:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = menu_buttons[action]
		InputMap.action_add_event(action,event)
	for entry: Array in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0],event)
		InputMap.action_set_deadzone(entry[0],0.35)
	for entry: Array in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["down",JOY_AXIS_LEFT_Y,1.0],["heal",JOY_AXIS_TRIGGER_LEFT,1.0],["burst",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0],event)
		InputMap.action_set_deadzone(entry[0],0.25)
	load_config()

func prompt(action: String) -> String:
	if pad_active: return PAD_NAMES.get(action,action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode)
	return action

func observe(event: InputEvent) -> bool:
	var before: bool = pad_active
	if event is InputEventJoypadButton and event.pressed: pad_active = true
	elif event is InputEventJoypadMotion and absf(event.axis_value)>0.45: pad_active = true
	elif event is InputEventKey and event.pressed: pad_active = false
	elif event is InputEventMouseButton and event.pressed: pad_active = false
	if before!=pad_active:
		changed.emit()
		game.stats_changed.emit()
	if capture_action.is_empty(): return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			capture_action = ""
			status = "已取消改键。"
		elif rebind(capture_action,event.physical_keycode): capture_action = ""
		changed.emit()
		return true
	return false

func rebind(action: String,code: int) -> bool:
	if not ACTIONS.has(action): return false
	if code in [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_F11,KEY_M,KEY_1,KEY_2,KEY_3,KEY_HOME,KEY_EQUAL,KEY_MINUS,KEY_S,KEY_DOWN]:
		status = "该键保留给菜单或系统，请选择其他按键。"
		return false
	for other: String in ACTIONS:
		if other==action: continue
		for event: InputEvent in InputMap.action_get_events(other):
			if event is InputEventKey and event.physical_keycode==code:
				status = "该键已用于「%s」，请先修改那一项。"%LABELS[ACTIONS.find(other)]
				return false
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey: InputMap.action_erase_event(action,event)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action,event)
	status = "%s 已改为 %s"%[LABELS[ACTIONS.find(action)],OS.get_keycode_string(code)]
	save_config()
	changed.emit()
	game.stats_changed.emit()
	return true

func reset_bindings() -> void:
	for action: String in ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey: InputMap.action_erase_event(action,event)
		for event: InputEvent in defaults[action]:
			if event is InputEventKey: InputMap.action_add_event(action,event)
	capture_action = ""
	status = "已恢复默认键盘布局，手柄与鼠标绑定保留。"
	save_config()
	changed.emit()
	game.stats_changed.emit()

func save_config() -> void:
	if game.test_mode: return
	var cfg: ConfigFile = ConfigFile.new()
	for action: String in ACTIONS:
		var keys: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey: keys.append(event.physical_keycode)
		cfg.set_value("keys",action,keys)
	cfg.set_value("comfort","lessons",lessons_enabled)
	DirAccess.make_dir_recursive_absolute(game.director.path(""))
	cfg.save(game.director.path("controls.cfg"))

func load_config() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(game.director.path("controls.cfg"))!=OK: return
	lessons_enabled = bool(cfg.get_value("comfort","lessons",true))
	for action: String in ACTIONS:
		var keys: Array = cfg.get_value("keys",action,[])
		if keys.is_empty(): continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey: InputMap.action_erase_event(action,event)
		for code: Variant in keys:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = int(code)
			InputMap.action_add_event(action,event)
