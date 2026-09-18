shader_type canvas_item;
render_mode unshaded;

// Final-image treatment: the weave stays on the cloth, only the lamp and
// faint grain move. Pixel-sized softness keeps small menu text readable.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float cloth_strength : hint_range(0.0, 0.25) = 0.105;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.012;
uniform float edge_shade : hint_range(0.0, 0.4) = 0.14;
uniform float softness : hint_range(0.0, 1.0) = 0.28;
uniform float lamp_motion : hint_range(0.0, 0.05) = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE;
	vec3 original = texture(screen_texture, uv).rgb;
	vec3 softened = (texture(screen_texture, uv + vec2(pixel.x, 0.0)).rgb
		+ texture(screen_texture, uv - vec2(pixel.x, 0.0)).rgb
		+ texture(screen_texture, uv + vec2(0.0, pixel.y)).rgb
		+ texture(screen_texture, uv - vec2(0.0, pixel.y)).rgb) * 0.25;
	vec3 color = mix(original, softened, softness);

	// Use a height-relative fabric scale; cap thread density on small windows
	// to avoid subpixel moire. Uneven yarn breaks up a perfect digital grid.
	vec2 cloth_uv = uv * vec2(pixel.y / pixel.x, 1.0);
	float threads = min(340.0, 0.25 / pixel.y);
	vec2 weave_uv = cloth_uv * threads;
	float warp = sin((weave_uv.x + noise(vec2(weave_uv.y * 0.08, 3.0)) * 0.45) * 6.283185);
	float weft = sin((weave_uv.y + noise(vec2(7.0, weave_uv.x * 0.09)) * 0.45) * 6.283185);
	float weave = warp * 0.38 + weft * 0.38 + warp * weft * 0.24;
	float mottling = noise(cloth_uv * 7.0) * 0.65 + noise(cloth_uv * 23.0) * 0.35;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color *= 1.0 + (weave * 0.48 + (mottling - 0.5) * 1.3)
		* cloth_strength * mix(0.35, 1.0, luminance);

	// Slightly lifted ink blacks and cream highlights, without another sepia
	// wash over an already amber stage.
	color = color * vec3(0.965, 0.955, 0.935) + vec3(0.018, 0.014, 0.010);
	vec2 lamp_center = vec2(0.47, 0.43) + vec2(sin(TIME * 0.27), sin(TIME * 0.19)) * 0.008;
	float distance_from_lamp = length((uv - lamp_center) * vec2(1.08, 0.92));
	color *= 1.0 - edge_shade * smoothstep(0.16, 0.72, distance_from_lamp);
	color *= 1.0 + lamp_motion * (sin(TIME * 1.13) * 0.65 + sin(TIME * 2.37) * 0.35);
	float grain = hash(floor(uv / pixel) + vec2(floor(TIME * 12.0), 0.0)) - 0.5;
	color += grain * grain_strength;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
