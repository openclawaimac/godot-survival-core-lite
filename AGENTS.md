# AGENTS.md: Godot Survival Core Lite

## What this is
Godot Survival Core Lite is a free, MIT-licensed **Godot 4 survival crafting starter kit / template** written in typed GDScript for Godot 4.7 (tested on 4.7.2). It provides headless-testable game logic plus a small demo. The paid Pro edition (€12, commercial EULA) has the same API plus more features: https://huginhelm.itch.io/godot-survival-core
Website: https://openclawaimac.github.io/godot-survival-core/

## Structure
- `addons/survival_core/survival_stats.gd` – SurvivalStats: hunger/thirst, starvation, regen, died signal
- `addons/survival_core/day_night_clock.gd` – DayNightClock: time of day, phases, light_level()
- `addons/survival_core/inventory.gd` – Inventory: slots and stacks
- `addons/survival_core/recipe_book.gd` – RecipeBook: data-driven crafting
- `addons/survival_core/gatherable.gd` – Gatherable resource nodes with hits, depletion, respawn
- `examples/` – demo.tscn (main scene, CC0 sprites), lite_demo, data/content.json
- `tests/` – strict headless suite
- `tools/` – run_tests.sh, make_release.sh

## Run the tests
```bash
godot --headless --path . --import   # once, after clone or after adding a class_name
bash tools/run_tests.sh /path/to/godot   # or set GODOT=...; must print "RESULT: PASS 48 checks" and exit 0
```
The runner fails on non-zero exit, any `SCRIPT ERROR`, or a missing `RESULT: PASS` line.

## How to extend
- New items, recipes, needs and gatherables: edit `examples/data/content.json` – content is data.
- Time-driven systems expose `tick(delta)`/`advance(delta)`; set `auto_tick = false` in tests.
- Keep systems pure logic (no scene-tree dependencies) so they stay headless-testable.
- Add tests for new behaviour: a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`), then update `tests/expected.json`.

## Rules
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --import` after adding a class_name.
- Tests: `tools/run_tests.sh /path/to/godot` must print `RESULT: PASS`. Add a section (`await H.section("test_x", test_x)`) and update `tests/expected.json`.
- Systems are pure logic in `addons/survival_core/`. Time-driven systems expose `tick(delta)`/`advance(delta)`. Tests set `auto_tick = false`.
- Content is data (`examples/data/content.json`). Keep APIs identical to the Pro edition.

## Lite vs Pro
Lite = free, MIT, 48 tests, core systems + minimal demo. Pro = €12, commercial per-seat EULA, 144 tests, full feature set and playable demo, same API. See README.md "Lite vs Pro" or https://openclawaimac.github.io/godot-survival-core/. Get Pro: https://huginhelm.itch.io/godot-survival-core
