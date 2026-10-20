shader_type spatial;
// Ash-covered soil with cracks; optional build grid.

uniform float grid_alpha = 0.0;
uniform vec2 map_size = vec2(64.0, 64.0);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 0.3) * 0.5 + noise(p * 1.6) * 0.3 + noise(p * 7.0) * 0.2;
	vec3 col = mix(vec3(0.085, 0.08, 0.072), vec3(0.19, 0.175, 0.15), n);
	float crack = 1.0 - smoothstep(0.0, 0.035, abs(noise(p * 0.8 + 3.1) - 0.5));
	col *= 1.0 - crack * 0.45;
	float ash = smoothstep(0.62, 0.8, noise(p * 0.45 + 11.0));
	col = mix(col, vec3(0.28, 0.27, 0.25), ash * 0.35);
	vec2 g = abs(fract(p) - 0.5);
	float line = smoothstep(0.465, 0.495, max(g.x, g.y));
	col = mix(col, vec3(0.95, 0.55, 0.2), line * grid_alpha * 0.35);
	vec2 edge = min(p, map_size - p);
	float border = clamp(min(edge.x, edge.y) / 4.0, 0.0, 1.0);
	col *= mix(0.25, 1.0, border);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.2;
}
