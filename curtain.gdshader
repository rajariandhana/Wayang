shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, depth_test_disabled;

uniform sampler2D cloth_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 curtain_tint : source_color = vec4(0.16, 0.032, 0.022, 1.0);
uniform float open_amount : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// A restrained vertical ripple makes the panels read as hanging fabric.
	// It tightens as they gather at the wings.
	float folds = sin(UV.x * 50.0) * mix(0.018, 0.045, open_amount);
	VERTEX.z += folds * (0.25 + UV.y * 0.75);
}

void fragment() {
	vec4 cloth = texture(cloth_texture, UV);
	float broad_fold = 0.72 + 0.28 * pow(abs(cos(UV.x * 25.0)), 1.6);
	float edge_shadow = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
	ALBEDO = cloth.rgb * curtain_tint.rgb * broad_fold * mix(0.72, 1.0, edge_shadow);
	ROUGHNESS = 0.92;
	ALPHA = cloth.a * curtain_tint.a;
}
