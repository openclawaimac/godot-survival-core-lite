class_name Gatherable
extends Node2D
## A resource node (tree, rock, bush). Each hit yields items; depletes then respawns.

signal depleted()

@export var item: StringName = &"wood"
@export var yield_per_hit: int = 1
@export var hits: int = 3
@export var respawn_sec: float = 30.0
@export var color: Color = Color(0.2, 0.6, 0.25)
@export var radius: float = 12.0

var remaining: int = 3
var _respawn_left: float = 0.0

func _ready() -> void:
	remaining = hits

func is_available() -> bool:
	return remaining > 0

func harvest(inv: Inventory) -> int:
	if remaining <= 0:
		return 0
	var got: int = inv.add(item, yield_per_hit)
	if got > 0:
		remaining -= 1
		if remaining == 0:
			_respawn_left = respawn_sec
			depleted.emit()
		queue_redraw()
	return got

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if remaining == 0:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			remaining = hits
			queue_redraw()

## JSON-safe snapshot including position and respawn timer.
func to_save() -> Dictionary:
	return {"item": String(item), "x": position.x, "y": position.y, "hits": hits,
		"yield_per_hit": yield_per_hit, "respawn_sec": respawn_sec, "remaining": remaining,
		"respawn_left": _respawn_left, "color": color.to_html()}

## Restores a snapshot made by to_save().
func load_save(d: Dictionary) -> void:
	item = StringName(str(d.get("item", item)))
	position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	hits = int(d.get("hits", hits))
	yield_per_hit = int(d.get("yield_per_hit", yield_per_hit))
	respawn_sec = float(d.get("respawn_sec", respawn_sec))
	remaining = int(d.get("remaining", hits))
	_respawn_left = float(d.get("respawn_left", 0.0))
	color = Color.from_string(str(d.get("color", "")), color)
	queue_redraw()

## Debug/fallback visual (coloured circle) so the node is visible without art.
## Games normally hide it or subclass (see examples' VisualGatherable).
func _draw() -> void:
	var c: Color = color if remaining > 0 else color.darkened(0.7)
	draw_circle(Vector2.ZERO, radius, c)
