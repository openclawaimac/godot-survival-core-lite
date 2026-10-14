class_name DayNightClock
extends Node
## 0..1 time of day. Emits phase changes (dawn/day/dusk/night) and new days.

signal phase_changed(phase: StringName)
signal day_started(day: int)

@export var day_length_sec: float = 120.0
@export var start_time: float = 0.3
@export var auto_tick: bool = true

var time_of_day: float = 0.3
var day: int = 1
var phase: StringName = &""

func _ready() -> void:
	time_of_day = start_time
	phase = phase_for(time_of_day)

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func tick(delta: float) -> void:
	time_of_day += delta / day_length_sec
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_started.emit(day)
	var p: StringName = phase_for(time_of_day)
	if p != phase:
		phase = p
		phase_changed.emit(p)

static func phase_for(t: float) -> StringName:
	if t < 0.2: return &"night"
	if t < 0.3: return &"dawn"
	if t < 0.7: return &"day"
	if t < 0.8: return &"dusk"
	return &"night"

## JSON-safe snapshot: {time_of_day, day}.
func to_save() -> Dictionary:
	return {"time_of_day": time_of_day, "day": day}

## Restores a snapshot; does not emit phase_changed/day_started.
func load_save(d: Dictionary) -> void:
	time_of_day = fposmod(float(d.get("time_of_day", start_time)), 1.0)
	day = int(d.get("day", 1))
	phase = phase_for(time_of_day)

func is_night() -> bool:
	return phase == &"night"

## Ambient light multiplier 0.25..1 (smooth cosine), for CanvasModulate.
func light_level() -> float:
	return 0.625 - 0.375 * cos(time_of_day * TAU)
