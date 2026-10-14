class_name SurvivalStats
extends Node
## Needs (hunger, thirst) drain over time; when a need hits 0 it damages health.
## Pure logic: call tick(delta) yourself or let _process do it.

signal need_changed(need: StringName, value: float)
signal died()

@export var max_value: float = 100.0
@export var hunger_per_sec: float = 0.5
@export var thirst_per_sec: float = 0.8
@export var starve_damage_per_sec: float = 2.0
@export var regen_per_sec: float = 0.5 ## health regen while all needs > regen_threshold
@export var regen_threshold: float = 60.0
@export var auto_tick: bool = true

var health: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var is_dead: bool = false

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func tick(delta: float) -> void:
	if is_dead:
		return
	_set_need(&"hunger", hunger - hunger_per_sec * delta)
	_set_need(&"thirst", thirst - thirst_per_sec * delta)
	var starving: int = int(hunger <= 0.0) + int(thirst <= 0.0)
	if starving > 0:
		_set_need(&"health", health - starve_damage_per_sec * starving * delta)
	elif hunger >= regen_threshold and thirst >= regen_threshold:
		_set_need(&"health", health + regen_per_sec * delta)
	if health <= 0.0:
		is_dead = true
		died.emit()

## JSON-safe snapshot of needs.
func to_save() -> Dictionary:
	return {"health": health, "hunger": hunger, "thirst": thirst, "is_dead": is_dead}

## Restores a snapshot made by to_save().
func load_save(d: Dictionary) -> void:
	health = float(d.get("health", max_value))
	hunger = float(d.get("hunger", max_value))
	thirst = float(d.get("thirst", max_value))
	is_dead = bool(d.get("is_dead", false))

func restore(need: StringName, amount: float) -> void:
	match need:
		&"hunger": _set_need(need, hunger + amount)
		&"thirst": _set_need(need, thirst + amount)
		&"health": _set_need(need, health + amount)
		_: push_warning("unknown need %s" % need)

func _set_need(need: StringName, v: float) -> void:
	var c: float = clampf(v, 0.0, max_value)
	match need:
		&"hunger": hunger = c
		&"thirst": thirst = c
		&"health": health = c
	need_changed.emit(need, c)
