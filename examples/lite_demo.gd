extends Node2D
## Lite example scene: player dot (WASD), three gatherables, need bars (drawn),
## day/night clock. E gather (nearest in reach), 1-3 craft, F eat best food.
## Everything visible is drawn in code (no assets).

const SPEED: float = 220.0
const REACH: float = 60.0

var content: LiteContent
var stats: SurvivalStats
var clock: DayNightClock
var inv: Inventory = Inventory.new(8, 20)
var nodes: Array[Gatherable] = []
var player_pos: Vector2 = Vector2(600, 330)
var bars: Dictionary = {}
var info: Label
var last_msg: String = "E gather, 1-3 craft, F eat"

func _ready() -> void:
	content = LiteContent.load_file("res://examples/data/content.json")
	stats = SurvivalStats.new()
	add_child(stats)
	clock = DayNightClock.new()
	clock.day_length_sec = 120.0
	add_child(clock)
	for g: Gatherable in content.make_gatherables():
		add_child(g)
		nodes.append(g)
	var y: float = 20.0
	for need: String in ["health", "hunger", "thirst"]:
		var l: Label = Label.new()
		l.text = need.capitalize()
		l.position = Vector2(250, y)
		add_child(l)
		bars[need] = y
		y += 30.0
	info = Label.new()
	info.position = Vector2(20, 120)
	add_child(info)

func _process(delta: float) -> void:
	var v: Vector2 = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var wasd: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	move(((v + wasd).limit_length(1.0)) * SPEED * delta)
	var lines: Array[String] = ["Day %d  %s  light %.0f%%" % [clock.day, clock.phase, clock.light_level() * 100.0], last_msg, "Backpack:"]
	for id: StringName in inv.to_dict():
		lines.append("  %s x%d" % [content.name_of(id), inv.count(id)])
	var k: int = 1
	for r: StringName in content.recipes.recipe_ids():
		lines.append("%d: %s %s" % [k, content.name_of(r), "(ok)" if content.recipes.can_craft(inv, r) else ""])
		k += 1
	info.text = "\n".join(lines)
	queue_redraw()

func move(d: Vector2) -> void:
	player_pos = (player_pos + d).clamp(Vector2(16, 16), Vector2(1264, 704))

## E: harvest the nearest available gatherable in reach. Returns items gained.
func gather() -> int:
	var best: Gatherable = null
	for g: Gatherable in nodes:
		if g.is_available() and g.position.distance_to(player_pos) <= REACH and (best == null or g.position.distance_to(player_pos) < best.position.distance_to(player_pos)):
			best = g
	if best == null:
		last_msg = "Nothing in reach"
		return 0
	var got: int = best.harvest(inv)
	last_msg = "+%d %s" % [got, content.name_of(best.item)]
	return got

## 1-3: craft recipe number `i` (0-based). Returns true on success.
func craft(i: int) -> bool:
	var ids: Array[StringName] = content.recipes.recipe_ids()
	if i < 0 or i >= ids.size():
		return false
	var ok: bool = content.recipes.craft(inv, ids[i])
	last_msg = ("Crafted %s" % content.name_of(ids[i])) if ok else "Missing ingredients"
	return ok

## F: eat the most filling food in the backpack. Returns true if something was eaten.
func eat() -> bool:
	var best: StringName = &""
	for id: StringName in inv.to_dict():
		var f: Dictionary = content.food_of(id)
		if not f.is_empty() and (best == &"" or float(f.get("hunger", 0)) > float(content.food_of(best).get("hunger", 0))):
			best = id
	if best == &"":
		last_msg = "No food"
		return false
	inv.remove_all({best: 1} as Dictionary[StringName, int])
	var f2: Dictionary = content.food_of(best)
	stats.restore(&"hunger", float(f2.get("hunger", 0)))
	stats.restore(&"thirst", float(f2.get("thirst", 0)))
	last_msg = "Ate %s" % content.name_of(best)
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_E: gather()
		KEY_F: eat()
		KEY_1: craft(0)
		KEY_2: craft(1)
		KEY_3: craft(2)

func _draw() -> void:
	var light: float = clock.light_level()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.22, 0.42, 0.25).darkened(0.6 * (1.0 - light)))
	draw_arc(player_pos, REACH, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 1.0)
	draw_circle(player_pos, 12.0, Color(0.95, 0.85, 0.4))
	var cols: Dictionary = {"health": Color(0.85, 0.25, 0.3), "hunger": Color(0.9, 0.6, 0.2), "thirst": Color(0.3, 0.6, 0.95)}
	for need: String in bars:
		var r: Rect2 = Rect2(20, float(bars[need]) + 2.0, 220, 20)
		draw_rect(r, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(stats.get(need)) / stats.max_value, 0.0, 1.0), r.size.y)), cols[need])
