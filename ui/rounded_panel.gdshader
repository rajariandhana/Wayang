shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, depth_test_disabled;

uniform vec2 rect_size = vec2(1.0, 0.3);
uniform float radius : hint_range(0.0, 0.5) = 0.06;
uniform vec4 fill_color : source_color = vec4(0.14, 0.08, 0.04, 0.9);
uniform vec4 border_color : source_color = vec4(0.85, 0.62, 0.32, 1.0);
uniform float border_width : hint_range(0.0, 0.1) = 0.012;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	float dist = sd_rounded_box(p, rect_size * 0.5, radius);
	float aa = 0.006;
	float shape_alpha = 1.0 - smoothstep(0.0, aa, dist);
	float border_mix = 1.0 - smoothstep(0.0, aa, dist + border_width);
	vec3 col = mix(border_color.rgb, fill_color.rgb, border_mix);
	float a = mix(border_color.a, fill_color.a, border_mix);
	ALBEDO = col;
	ALPHA = shape_alpha * a;
}
