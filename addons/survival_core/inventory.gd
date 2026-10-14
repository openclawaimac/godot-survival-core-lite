class_name Inventory
extends RefCounted
## Slot-limited stacking inventory. Items are StringName ids.

signal changed()

var slots: int
var stack_size: int
var _items: Dictionary[StringName, int] = {}

func _init(p_slots: int = 12, p_stack: int = 50) -> void:
	slots = p_slots
	stack_size = p_stack

func count(id: StringName) -> int:
	return _items.get(id, 0)

func used_slots() -> int:
	var n: int = 0
	for id: StringName in _items:
		n += ceili(float(_items[id]) / stack_size)
	return n

## Adds as many as fit; returns how many were added.
func add(id: StringName, amount: int) -> int:
	var have: int = count(id)
	var free_in_stack: int = (stack_size - have % stack_size) % stack_size
	var free_slots: int = slots - used_slots()
	var room: int = free_in_stack + free_slots * stack_size
	var added: int = mini(amount, room)
	if added > 0:
		_items[id] = have + added
		changed.emit()
	return added

func has_all(cost: Dictionary[StringName, int]) -> bool:
	for id: StringName in cost:
		if count(id) < cost[id]:
			return false
	return true

func remove_all(cost: Dictionary[StringName, int]) -> bool:
	if not has_all(cost):
		return false
	for id: StringName in cost:
		_items[id] -= cost[id]
		if _items[id] <= 0:
			_items.erase(id)
	changed.emit()
	return true

## Sets an exact amount (used by load and by containers). 0 removes the entry.
func set_count(id: StringName, amount: int) -> void:
	if amount <= 0:
		_items.erase(id)
	else:
		_items[id] = amount
	changed.emit()

## Removes everything and returns what was held.
func take_all() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = _items.duplicate()
	_items.clear()
	changed.emit()
	return out

## JSON-safe snapshot: {slots, stack_size, items: {id: count}}.
func to_save() -> Dictionary:
	var items: Dictionary = {}
	for id: StringName in _items:
		items[String(id)] = _items[id]
	return {"slots": slots, "stack_size": stack_size, "items": items}

## Restores a snapshot made by to_save(). Replaces current contents.
func load_save(d: Dictionary) -> void:
	slots = int(d.get("slots", slots))
	stack_size = int(d.get("stack_size", stack_size))
	_items.clear()
	var items: Dictionary = d.get("items", {})
	for k: Variant in items:
		var n: int = int(items[k])
		if n > 0:
			_items[StringName(str(k))] = n
	changed.emit()

func to_dict() -> Dictionary[StringName, int]:
	return _items.duplicate()
