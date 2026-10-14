class_name RecipeBook
extends RefCounted
## Data-driven recipes: id -> {inputs, output_count, station}.

var _recipes: Dictionary[StringName, Dictionary] = {}

func add_recipe(output: StringName, inputs: Dictionary[StringName, int], output_count: int = 1, station: StringName = &"") -> void:
	_recipes[output] = {"inputs": inputs, "count": output_count, "station": station}

func can_craft(inv: Inventory, output: StringName, near_station: StringName = &"") -> bool:
	if not _recipes.has(output):
		return false
	var r: Dictionary = _recipes[output]
	var st: StringName = r["station"]
	if st != &"" and st != near_station:
		return false
	var inputs: Dictionary[StringName, int] = r["inputs"]
	return inv.has_all(inputs)

func craft(inv: Inventory, output: StringName, near_station: StringName = &"") -> bool:
	if not can_craft(inv, output, near_station):
		return false
	var r: Dictionary = _recipes[output]
	var inputs: Dictionary[StringName, int] = r["inputs"]
	inv.remove_all(inputs)
	var n: int = r["count"]
	if inv.add(output, n) < n:
		push_warning("inventory full, crafted items partly lost")
	return true

func recipe_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_recipes.keys())
	return out

func has_recipe(output: StringName) -> bool:
	return _recipes.has(output)

## Inputs required for `output` (empty if unknown). Useful for crafting UIs.
func inputs_of(output: StringName) -> Dictionary[StringName, int]:
	var empty: Dictionary[StringName, int] = {}
	if not _recipes.has(output):
		return empty
	var inputs: Dictionary[StringName, int] = _recipes[output]["inputs"]
	return inputs.duplicate()

## Station tag required for `output` ("" = none).
func station_of(output: StringName) -> StringName:
	return _recipes[output]["station"] if _recipes.has(output) else &""

func output_count_of(output: StringName) -> int:
	return int(_recipes[output]["count"]) if _recipes.has(output) else 0
