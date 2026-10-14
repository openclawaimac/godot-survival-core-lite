# AGENTS.md: Godot Survival Core Lite
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --import` after adding a class_name.
- Tests: `tools/run_tests.sh /path/to/godot` must print `RESULT: PASS`. Add a section (`await H.section("test_x", test_x)`) and update `tests/expected.json`.
- Systems are pure logic in `addons/survival_core/`. Time-driven systems expose `tick(delta)`/`advance(delta)`. Tests set `auto_tick = false`.
- Content is data (`examples/data/content.json`). Keep APIs identical to the Pro edition.
