extends SceneTree
## Lite headless tests: tools/run_tests.sh (strict) or
## godot --headless --path . -s res://tests/run_tests.gd  (exit 0 = pass).
## Subset of the Pro suite for the Lite modules, plus Lite-only checks.

const Harness = preload("res://tests/harness.gd")
var H: Harness

func check(cond: bool, msg: String) -> void:
	H.check(cond, msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	H = Harness.new()
	if Harness.selftest_mode() == "crash":
		await H.section("harness_crash_selftest", H.crash_selftest)
	elif Harness.selftest_mode() == "exit":
		quit(0)
		return
	await H.section("test_stats", test_stats)
	await H.section("test_clock", test_clock)
	await H.section("test_inventory", test_inventory)
	await H.section("test_crafting", test_crafting)
	await H.section("test_gather", test_gather)
	await H.section("test_save_snapshots", test_save_snapshots)
	await H.section("test_lite_content", test_lite_content)
	await H.section("test_lite_scope", test_lite_scope)
	await H.section("test_lite_demo", test_lite_demo)
	await H.section("test_demo", test_demo)
	quit(H.finish())

func test_stats() -> void:
	print("stats")
	var s: SurvivalStats = SurvivalStats.new()
	s.auto_tick = false
	s.tick(10.0)
	check(is_equal_approx(s.hunger, 95.0) and is_equal_approx(s.thirst, 92.0), "needs drain at configured rates")
	check(is_equal_approx(s.health, 100.0), "no damage while fed")
	s.hunger = 0.0
	s.thirst = 0.0
	var died: Array[bool] = [false]
	s.died.connect(func() -> void: died[0] = true)
	s.tick(10.0)
	check(is_equal_approx(s.health, 60.0), "both needs empty -> double starve damage (got %s)" % s.health)
	s.tick(100.0)
	check(died[0] and s.is_dead, "dies at 0 health")
	s.free()

func test_clock() -> void:
	print("clock")
	var c: DayNightClock = DayNightClock.new()
	c.auto_tick = false
	c.day_length_sec = 100.0
	c.start_time = 0.5
	root.add_child(c)
	var phases: Array[StringName] = []
	c.phase_changed.connect(func(p: StringName) -> void: phases.append(p))
	check(c.phase == &"day", "starts in day at noon")
	c.tick(25.0)
	c.tick(10.0)
	check(phases.size() == 2 and phases[0] == &"dusk" and phases[1] == &"night" and c.is_night(), "dusk then night (%s)" % [phases])
	c.tick(20.0)
	check(c.day == 2, "rolls to day 2")
	check(c.light_level() < 0.5, "dark at night")
	c.free()

func test_inventory() -> void:
	print("inventory")
	var inv: Inventory = Inventory.new(2, 10)
	check(inv.add(&"wood", 15) == 15 and inv.used_slots() == 2, "stacks across slots")
	check(inv.add(&"wood", 10) == 5, "caps at capacity")
	check(inv.add(&"stone", 1) == 0, "no slot for new item")
	check(not inv.remove_all({&"wood": 99} as Dictionary[StringName, int]) and inv.count(&"wood") == 20, "atomic failed remove")

func test_crafting() -> void:
	print("crafting")
	var inv: Inventory = Inventory.new()
	var rb: RecipeBook = RecipeBook.new()
	rb.add_recipe(&"campfire", {&"wood": 5, &"stone": 2} as Dictionary[StringName, int])
	rb.add_recipe(&"stew", {&"meat": 1} as Dictionary[StringName, int], 1, &"campfire")
	inv.add(&"wood", 5)
	check(not rb.craft(inv, &"campfire"), "missing stone -> fail")
	inv.add(&"stone", 2)
	check(rb.craft(inv, &"campfire") and inv.count(&"campfire") == 1 and inv.count(&"wood") == 0, "craft consumes inputs")
	inv.add(&"meat", 1)
	check(not rb.can_craft(inv, &"stew"), "station recipe needs station")
	check(rb.craft(inv, &"stew", &"campfire"), "station recipe works near station")

func test_gather() -> void:
	print("gather")
	var n: Gatherable = Gatherable.new()
	n.hits = 2
	n.respawn_sec = 5.0
	root.add_child(n)
	var inv: Inventory = Inventory.new()
	n.harvest(inv)
	n.harvest(inv)
	check(inv.count(&"wood") == 2 and not n.is_available(), "depletes after hits")
	check(n.harvest(inv) == 0, "no yield when depleted")
	n.advance(6.0)
	check(n.is_available(), "respawns")
	n.free()

func test_save_snapshots() -> void:
	print("save snapshots (to_save / load_save)")
	var inv: Inventory = Inventory.new(4, 10)
	inv.add(&"wood", 7)
	inv.add(&"stone", 2)
	var s: SurvivalStats = SurvivalStats.new()
	s.auto_tick = false
	s.tick(20.0)
	var data: Dictionary = {"inventory": inv.to_save(), "stats": s.to_save()}
	var back: Variant = JSON.parse_string(JSON.stringify(data))
	var inv2: Inventory = Inventory.new(4, 10)
	inv2.load_save((back as Dictionary)["inventory"])
	var s2: SurvivalStats = SurvivalStats.new()
	s2.load_save((back as Dictionary)["stats"])
	check(inv2.count(&"wood") == 7 and inv2.count(&"stone") == 2, "inventory survives a JSON round trip")
	check(is_equal_approx(s2.hunger, s.hunger) and is_equal_approx(s2.thirst, s.thirst), "needs survive a JSON round trip")
	s.free()
	s2.free()

func test_lite_content() -> void:
	print("Lite content.json")
	var c: LiteContent = LiteContent.load_file("res://examples/data/content.json")
	check(c.items.size() == 5 and c.recipes.recipe_ids().size() == 3 and c.gatherables.size() == 3, "5 items, 3 recipes, 3 gatherables")
	var inv: Inventory = Inventory.new()
	inv.add(&"wood", 2)
	check(c.recipes.craft(inv, &"torch") and inv.count(&"torch") == 1, "hand recipe from data crafts")
	check(c.food_of(&"berries").get("hunger", 0) == 15 and c.food_of(&"wood").is_empty(), "food values from data")
	var gs: Array[Gatherable] = c.make_gatherables()
	check(gs.size() == 3 and gs[0].item == &"wood" and gs[0].remaining == 3, "gatherables built from data")
	for g: Gatherable in gs:
		g.free()

func test_lite_scope() -> void:
	print("Lite scope (no Pro modules)")
	var bad: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		if str(cls["class"]) in ["BuildGrid", "BaseBuilder", "StructureDef", "SaveGame", "WorldNodes"]:
			bad.append(str(cls["class"]))
	check(bad.is_empty(), "no Pro classes in the Lite project %s" % [bad])

func test_lite_demo() -> void:
	print("Lite example scene")
	var d: Node = (load("res://examples/lite_demo.tscn") as PackedScene).instantiate()
	root.add_child(d)
	for i: int in 3:
		await process_frame
	var inv: Inventory = d.get("inv")
	d.set("player_pos", Vector2(420, 300))
	check(d.call("gather") == 1 and inv.count(&"wood") == 1, "E gathers wood from the tree in reach")
	d.call("gather")
	check(d.call("craft", 0) and inv.count(&"torch") == 1, "1 crafts a torch from 2 wood")
	d.set("player_pos", Vector2(600, 470))
	d.call("gather")
	var st: SurvivalStats = d.get("stats")
	st.hunger = 50.0
	check(d.call("eat") and st.hunger > 50.0, "F eats berries and restores hunger")
	d.set("player_pos", Vector2(50, 50))
	check(d.call("gather") == 0, "nothing in reach far away")
	d.queue_free()
	await process_frame

func test_demo() -> void:
	print("CC0 sprite demo + F5/F9 save")
	const Demo = preload("res://examples/demo.gd")
	var g: Gatherable = Gatherable.new()
	g.item = &"wood"
	g.remaining = 1
	check(Demo.sprite_for(g) == "tree", "a harvestable tree uses the tree sprite")
	g.remaining = 0
	check(Demo.sprite_for(g) == "stump", "a depleted tree shows a stump")
	g.free()
	check(Demo.walk_region(&"left", 2) == Rect2(32, 32, 16, 16), "walk sheet: column = direction, row = frame")
	check(Demo.dir_for(Vector2(0, -1), &"down") == &"up" and Demo.dir_for(Vector2.ZERO, &"left") == &"left", "facing follows movement and holds when idle")
	var missing: Array[String] = []
	for n: String in ["tree", "stump", "rock", "stones_flat", "berry_bush", "bush", "player_sheet", "shadow", "grass_4", "flower_3", "tall_grass", "tree_cluster", "tree_cluster_b"]:
		if not ResourceLoader.exists(Demo.NA % n):
			missing.append(n)
	for n: String in ["gather_wood", "gather_stone", "gather_berries", "eat", "craft", "error"]:
		if not ResourceLoader.exists("res://assets/sfx/%s.ogg" % n):
			missing.append(n)
	check(missing.is_empty(), "every sprite and sound the demo uses is shipped %s" % [missing])
	for f: String in ["ninja-adventure-LICENSE.txt", "kenney_rpg-audio-License.txt", "kenney_impact-sounds-License.txt", "kenney_interface-sounds-License.txt"]:
		check(FileAccess.file_exists("res://assets/sources/" + f), "licence file " + f)
	var d: Node = (load("res://examples/demo.tscn") as PackedScene).instantiate()
	d.set("save_path", "user://test_demo_save.json")
	root.add_child(d)
	for i: int in 3:
		await process_frame
	var inv: Inventory = d.get("inv")
	d.set("player_pos", Vector2(420, 300))
	check(d.call("gather") == 1 and inv.count(&"wood") == 1, "demo inherits gathering from the Lite example")
	d.call("move", Vector2(30, 0))
	check(d.get("facing") == &"right", "moving right faces right")
	var st: SurvivalStats = d.get("stats")
	st.hunger = 40.0
	check(d.call("save_game") and FileAccess.file_exists("user://test_demo_save.json"), "F5 writes the save file")
	var pos: Vector2 = d.get("player_pos")
	d.set("player_pos", Vector2(100, 600))
	inv.add(&"stone", 5)
	st.hunger = 90.0
	check(d.call("load_game"), "F9 loads the save file")
	check(d.get("player_pos") == pos and inv.count(&"stone") == 0 and inv.count(&"wood") == 1 and is_equal_approx(st.hunger, 40.0), "load restores position, backpack and needs")
	var trees: Array = d.get("nodes")
	check((trees[0] as Gatherable).remaining == 2, "load restores gatherable state")
	check(not d.call("restore", {"format": "other", "version": 1}), "foreign save data is refused")
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	d.set("last_msg", "")
	d.call("_unhandled_key_input", ev)
	check(str(d.get("last_msg")).begins_with("Saved"), "the F5 key is wired to save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_demo_save.json"))
	d.set("save_path", "user://does_not_exist.json")
	check(not d.call("load_game"), "F9 without a save reports it and changes nothing")
	d.queue_free()
	await process_frame

