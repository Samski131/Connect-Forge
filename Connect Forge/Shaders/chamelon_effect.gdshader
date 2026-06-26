/*
Adapted from:
Godot Shaders - Teleport Effect
CC0

Modified for a multi-sprite chameleon token:
- screen-space noise prevents per-sprite splitting
- token-centred directional wipe keeps the transformation moving in one direction
*/

shader_type canvas_item;

uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_density = 0.08;
uniform float beam_size : hint_range(0.01, 0.15) = 0.06;
uniform float direction_strength : hint_range(0.0, 1.0) = 0.75;
uniform float dissolve_height_pixels = 120.0;

uniform vec2 token_center_screen = vec2(0.0, 0.0);
uniform vec4 beam_color : source_color = vec4(0.35, 1.0, 0.7, 1.0);

vec2 random(vec2 uv) {
	uv = vec2(
		dot(uv, vec2(127.1, 311.7)),
		dot(uv, vec2(269.5, 183.3))
	);
	
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise_fn(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);

	return mix(
		mix(
			dot(random(uv_index + vec2(0.0, 0.0)), uv_fract - vec2(0.0, 0.0)),
			dot(random(uv_index + vec2(1.0, 0.0)), uv_fract - vec2(1.0, 0.0)),
			blur.x
		),
		mix(
			dot(random(uv_index + vec2(0.0, 1.0)), uv_fract - vec2(0.0, 1.0)),
			dot(random(uv_index + vec2(1.0, 1.0)), uv_fract - vec2(1.0, 1.0)),
			blur.x
		),
		blur.y
	) * 0.5 + 0.5;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	
	vec2 dissolve_uv = FRAGCOORD.xy * noise_density;
	float noise_value = noise_fn(dissolve_uv);
	
	float local_y = (FRAGCOORD.y - token_center_screen.y) / dissolve_height_pixels + 0.5;
	local_y = clamp(local_y, 0.0, 1.0);
	
	float directional_value = 1.0 - local_y;
	float dissolve_value = mix(noise_value, directional_value, direction_strength);
	
	float d1 = step(dissolve_progress, dissolve_value);
	float d2 = step(dissolve_progress - beam_size, dissolve_value);
	
	vec3 beam = vec3(d2 - d1) * beam_color.rgb;
	
	tex.rgb += beam;
	tex.a *= d2;
	
	COLOR = tex;
}