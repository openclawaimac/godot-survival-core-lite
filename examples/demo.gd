extends "res://examples/lite_demo.gd"
## Survival Core Lite demo: the Lite example logic (lite_demo.gd) drawn with CC0
## Ninja Adventure sprites and Kenney sfx. WASD move, E gather, 1-3 craft, F eat,
## F5 save, F9 load (user://survival_lite_demo.json). Assets: ASSET_LICENSES.md.

const NA: String = "res://assets/sprites/na/%s.png"
const S: float = 3.0
const SAVE_FORMAT: String = "survival-core-lite-demo"
const SPRITE_FULL: Dictionary = {"wood": "tree", "stone": "rock", "berries": "berry_bush"}
const SPRITE_EMPTY: Dictionary = {"wood": "stump", "stone": "stones_flat", "berries": "bush"}
const SFX: Dictionary = {"wood": "gather_wood", "stone": "gather_stone", "berries": "gather_berries"}

var save_path: String = "user://survival_lite_demo.json"
var facing: StringName = &"down"
var walk_frame: int = 0
var _stride: float = 0.0
var _tex: Dictionary[String, Texture2D] = {}
var _sfx: Dictionary[String, AudioStreamPlayer] = {}
var _decor: Array[Vector3] = []

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for g: Gatherable in nodes:
		g.visible = false          # drawn here with sprites instead of debug circles
	for n: String in ["gather_wood", "gather_stone", "gather_berries", "eat", "craft", "error"]:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.ogg" % n) as AudioStream
		p.volume_db = -6.0
		add_child(p)
		_sfx[n] = p
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 16:          # x, y, kind (0-3 flowers, 4 tall grass)
		_decor.append(Vector3(rng.randf_range(40, 1240), rng.randf_range(130, 560), rng.randi_range(0, 4)))
	for c: Node in get_children():
		if c is Label:
			(c as Label).add_theme_constant_override("outline_size", 6)
			(c as Label).add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	info.position = Vector2(960, 16)
	last_msg = "E gather  1-3 craft  F eat  F5 save  F9 load"

func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(NA % name) as Texture2D
	return _tex[name]

## Sprite for a gatherable: full while harvestable, depleted look while respawning.
static func sprite_for(g: Gatherable) -> String:
	var key: String = String(g.item)
	return str((SPRITE_FULL if g.is_available() else SPRITE_EMPTY).get(key, "bush"))

## Walk-sheet region: one column per direction (down, up, left, right), row = frame.
static func walk_region(dir: StringName, frame: int) -> Rect2:
	return Rect2([&"down", &"up", &"left", &"right"].find(dir) * 16, frame * 16, 16, 16)

static func dir_for(v: Vector2, previous: StringName) -> StringName:
	if v.length() < 0.01:
		return previous
	if absf(v.x) > absf(v.y):
		return &"right" if v.x > 0.0 else &"left"
	return &"down" if v.y > 0.0 else &"up"

func move(d: Vector2) -> void:
	var before: Vector2 = player_pos
	super.move(d)
	var moved: Vector2 = player_pos - before
	facing = dir_for(moved, facing)
	if moved.length() > 0.01:
		_stride += moved.length()
		walk_frame = int(_stride / 18.0) % 4
	else:
		walk_frame = 0

func _play(n: String) -> void:
	if _sfx.has(n) and DisplayServer.get_name() != "headless":
		_sfx[n].play()

func gather() -> int:
	var got: int = super.gather()
	if got > 0:
		_play(str(SFX.get(String(_last_item()), "gather_wood")))
	else:
		_play("error")
	return got

func _last_item() -> StringName:
	for id: StringName in [&"wood", &"stone", &"berries"]:
		if last_msg.ends_with(content.name_of(id)):
			return id
	return &""

func craft(i: int) -> bool:
	var ok: bool = super.craft(i)
	_play("craft" if ok else "error")
	return ok

func eat() -> bool:
	var ok: bool = super.eat()
	_play("eat" if ok else "error")
	return ok

## Snapshot of the whole demo using each module's to_save().
func snapshot() -> Dictionary:
	var gs: Array = []
	for g: Gatherable in nodes:
		gs.append(g.to_save())
	return {"format": SAVE_FORMAT, "version": 1, "player": [player_pos.x, player_pos.y],
		"inventory": inv.to_save(), "stats": stats.to_save(), "clock": clock.to_save(), "gatherables": gs}

## Restores snapshot(). Returns false (and changes nothing) for foreign data.
func restore(d: Dictionary) -> bool:
	if str(d.get("format", "")) != SAVE_FORMAT or int(d.get("version", 0)) != 1:
		return false
	var p: Array = d.get("player", [player_pos.x, player_pos.y])
	player_pos = Vector2(float(p[0]), float(p[1]))
	inv.load_save(d.get("inventory", {}))
	stats.load_save(d.get("stats", {}))
	clock.load_save(d.get("clock", {}))
	var gs: Array = d.get("gatherables", [])
	for i: int in mini(gs.size(), nodes.size()):
		nodes[i].load_save(gs[i])
	return true

## F5
func save_game() -> bool:
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		last_msg = "Save failed"
		return false
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	last_msg = "Saved (F9 to load)"
	_play("craft")
	return true

## F9
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		last_msg = "No save yet (F5)"
		_play("error")
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var ok: bool = d is Dictionary and restore(d as Dictionary)
	last_msg = "Loaded" if ok else "Save file not recognised"
	_play("craft" if ok else "error")
	return ok

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode in [KEY_F5, KEY_F9]:
		if k.keycode == KEY_F5:
			save_game()
		else:
			load_game()
		return
	super._unhandled_key_input(event)

func _sprite(name: String, center_bottom: Vector2) -> void:
	var t: Texture2D = tex(name)
	var sz: Vector2 = t.get_size() * S
	draw_texture_rect(t, Rect2(center_bottom - Vector2(sz.x * 0.5, sz.y), sz), false)

func _draw() -> void:
	for y: int in 15:
		for x: int in 27:
			draw_texture_rect(tex("grass_%d" % ((x * 5 + y * 3 + (x * y) % 7) % 5)), Rect2(x * 48, y * 48, 48, 48), false)
	for i: int in 4:
		draw_texture_rect(tex("tree_cluster" if i % 2 == 0 else "tree_cluster_b"), Rect2(-60 + i * 340, 590, 192, 144), false)
	for d: Vector3 in _decor:
		var dt: Texture2D = tex("tall_grass" if int(d.z) == 4 else "flower_%d" % int(d.z))
		draw_texture_rect(dt, Rect2(Vector2(d.x - 16, d.y - 32), Vector2(32, 32)), false)
	var draw_list: Array = []
	for g: Gatherable in nodes:
		draw_list.append([g.position.y, sprite_for(g), g.position])
	draw_list.append([player_pos.y, "", player_pos])
	draw_list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e: Array in draw_list:
		var pos: Vector2 = e[2]
		var shadow: Texture2D = tex("shadow")
		draw_texture_rect(shadow, Rect2(pos - Vector2(18, 10), Vector2(36, 24)), false, Color(1, 1, 1, 0.6))
		if str(e[1]) == "":
			draw_arc(pos + Vector2(0, -20), REACH, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 2.0)
			draw_texture_rect_region(tex("player_sheet"), Rect2(pos - Vector2(24, 44), Vector2(48, 48)), walk_region(facing, walk_frame))
		else:
			_sprite(str(e[1]), pos + Vector2(0, 6))
	var light: float = clock.light_level()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.05, 0.2, 0.55 * (1.0 - light)))
	draw_rect(Rect2(8, 8, 330, 104), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(950, 8, 322, 260), Color(0, 0, 0, 0.45))
	var cols: Dictionary = {"health": Color(0.85, 0.25, 0.3), "hunger": Color(0.9, 0.6, 0.2), "thirst": Color(0.3, 0.6, 0.95)}
	for need: String in bars:
		var r: Rect2 = Rect2(20, float(bars[need]) + 2.0, 220, 20)
		draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(stats.get(need)) / stats.max_value, 0.0, 1.0), r.size.y)), cols[need])
