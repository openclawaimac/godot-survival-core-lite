class_name LiteContent
extends RefCounted
## Loads examples/data/content.json into a RecipeBook and Gatherable nodes.
## Recipe "station" tags are kept as data: RecipeBook checks them, and Lite
## has no stations, so use "" (hand crafting). Pro adds stations via BaseBuilder.

var items: Dictionary = {}
var recipes: RecipeBook = RecipeBook.new()
var gatherables: Array = []

static func load_file(path: String) -> LiteContent:
	var c: LiteContent = LiteContent.new()
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		push_error("LiteContent: cannot parse %s" % path)
		return c
	var dd: Dictionary = d
	c.items = dd.get("items", {})
	c.gatherables = dd.get("gatherables", [])
	for r: Variant in dd.get("recipes", []):
		var rd_: Dictionary = r
		var inputs: Dictionary[StringName, int] = {}
		for k: Variant in (rd_.get("in", {}) as Dictionary):
			inputs[StringName(str(k))] = int(rd_["in"][k])
		c.recipes.add_recipe(StringName(str(rd_["out"])), inputs, int(rd_.get("count", 1)), StringName(str(rd_.get("station", ""))))
	return c

## Display name for an item id.
func name_of(id: StringName) -> String:
	return str((items.get(String(id), {}) as Dictionary).get("name", String(id).capitalize()))

## {"hunger": x, "thirst": y} if the item is edible, else empty.
func food_of(id: StringName) -> Dictionary:
	return (items.get(String(id), {}) as Dictionary).get("food", {})

## Creates the Gatherable nodes described in the data (caller adds them to the tree).
func make_gatherables() -> Array[Gatherable]:
	var out: Array[Gatherable] = []
	for g: Variant in gatherables:
		var n: Gatherable = Gatherable.new()
		n.load_save(g)
		n.remaining = n.hits
		out.append(n)
	return out
