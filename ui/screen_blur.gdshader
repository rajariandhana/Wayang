shader_type spatial;
render_mode unshaded, blend_mix, cull_back;

uniform sampler2D screen_tex : source_color;
uniform float blur_size : hint_range(0.0, 0.02) = 0.0035;
uniform float darken : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_size;
			col += texture(screen_tex, UV + offset);
			total += 1.0;
		}
	}
	ALBEDO = (col.rgb / total) * darken;
	ALPHA = col.a / total;
}
