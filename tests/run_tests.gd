extends SceneTree
## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_construction.gd",
	"res://tests/test_logistics.gd",
	"res://tests/test_power.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_waves.gd",
	"res://tests/test_save.gd",
	"res://tests/test_integration.gd",
	"res://tests/test_research.gd",
	"res://tests/test_tools.gd",
	"res://tests/test_platform.gd",
	"res://tests/test_visual.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		var script = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL não foi possível carregar ", path)
			failed += 1
			continue
		var suite = script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite._current = "%s::%s" % [path.get_file(), name]
			var before: int = suite.failures.size()
			suite.call(name)
			if suite.failures.size() > before:
				failed += 1
				for f in suite.failures.slice(before):
					printerr("FAIL ", f)
			else:
				print("ok   ", suite._current)
	print("\n%d testes, %d falharam (%d ms)" % [total, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 else 0)
