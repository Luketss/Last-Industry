extends "res://tests/test_base.gd"
## Geometry helpers used by the view (no rendering needed).

const Meshes = preload("res://src/view/meshes.gd")


func test_belt_curve_geometry() -> void:
	# Straight: enters at the back edge, leaves at the front edge.
	eq(Meshes.belt_point(0, 0.0), Vector2(-0.5, 0), "reta: entrada atrás")
	eq(Meshes.belt_point(0, 1.0), Vector2(0.5, 0), "reta: saída à frente")
	for shape in [-1, 1]:
		var a: Vector2 = Meshes.belt_point(shape, 0.0)
		var b: Vector2 = Meshes.belt_point(shape, 1.0)
		check(a.distance_to(Vector2(0, 0.5 * shape)) < 0.001, "curva %d entra pela lateral (%s)" % [shape, a])
		check(b.distance_to(Vector2(0.5, 0)) < 0.001, "curva %d sai pela frente (%s)" % [shape, b])
		var mid: Vector2 = Meshes.belt_point(shape, 0.5)
		check(absf(mid.x) <= 0.5 and absf(mid.y) <= 0.5, "curva %d fica dentro do tile" % shape)
