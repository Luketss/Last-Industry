shader_type spatial;
// Belt surface: rubber with amber chevrons that scroll in the direction of travel.
// UV.x runs across the belt (0..1), UV.y along it from entry (0) to exit (1).

uniform float speed = 1.0;            // 0 = stopped
uniform vec4 belt_color : source_color = vec4(0.10, 0.095, 0.09, 1.0);
uniform vec4 arrow_color : source_color = vec4(1.0, 0.68, 0.18, 1.0);
uniform float glow = 0.9;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	// Two chevrons per tile; edges lag behind the centre so they point forward.
	float v = UV.y * 2.0 - TIME * speed * 1.6 + across * 0.45;
	float f = fract(v);
	float chevron = smoothstep(0.0, 0.05, f) * (1.0 - smoothstep(0.2, 0.26, f));
	chevron *= 1.0 - smoothstep(0.78, 0.86, across);
	// Subtle transverse ribs for texture.
	float rib = step(0.5, fract(UV.y * 10.0 - TIME * speed * 8.0)) * 0.04;
	vec3 col = belt_color.rgb + rib;
	ALBEDO = mix(col, arrow_color.rgb, chevron * 0.85);
	EMISSION = arrow_color.rgb * chevron * glow;
	ROUGHNESS = 0.8;
}
