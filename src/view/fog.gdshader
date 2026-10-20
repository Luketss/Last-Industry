shader_type spatial;
// Fog of war curtain: a plane above the map that is opaque over unexplored cells.
// The camera is orthographic, so each fragment samples the fog texture where its
// view ray meets the ground; the curtain then lines up with the ground cells and
// still hides ruins, ore and creatures standing in the fog.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(64.0, 64.0);
uniform vec3 color = vec3(0.02, 0.018, 0.016);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 dir = -INV_VIEW_MATRIX[2].xyz;
	vec2 ground = (wpos + dir * (-wpos.y / dir.y)).xz;
	vec2 uv = ground / map_size;
	float fog = 1.0;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		fog = 1.0 - texture(fog_tex, uv).r;
	}
	float grain = hash(floor(ground * 2.0)) * 0.04;
	ALBEDO = color + grain;
	ALPHA = smoothstep(0.05, 0.85, fog) * 0.94;
}
