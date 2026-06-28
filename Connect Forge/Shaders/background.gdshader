shader_type canvas_item;

// Top of the base vertical background gradient.
uniform vec4 top_color : source_color = vec4(0.02, 0.10, 0.35, 1.0);

// Bottom of the base vertical background gradient.
uniform vec4 bottom_color : source_color = vec4(0.03, 0.01, 0.18, 1.0);

// Main glow colour blended into the background.
uniform vec4 accent_color : source_color = vec4(0.0, 0.75, 1.0, 1.0);

// Secondary glow colour blended into the background.
uniform vec4 second_accent_color : source_color = vec4(0.45, 0.1, 1.0, 1.0);

// Colour used for the repeating background pattern.
uniform vec4 pattern_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);

// Colour used around the screen edges for the vignette.
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.08, 1.0);

// Strength of the main glow.
uniform float accent_strength : hint_range(0.0, 1.0) = 0.32;

// Strength of the secondary glow.
uniform float second_accent_strength : hint_range(0.0, 1.0) = 0.22;

// Size of the main glow. Higher values spread it further.
uniform float accent_radius : hint_range(0.05, 1.5) = 0.75;

// Size of the secondary glow. Higher values spread it further.
uniform float second_accent_radius : hint_range(0.05, 1.5) = 0.85;

// Screen-space position of the main glow. Uses 0.0 to 1.0 UV coordinates.
uniform vec2 accent_position = vec2(0.82, 0.18);

// Screen-space position of the secondary glow. Uses 0.0 to 1.0 UV coordinates.
uniform vec2 second_accent_position = vec2(0.18, 0.88);

// Pattern shape selector. 0 dots, 1 diamonds, 2 squares, 3 hexes, 4 diagonal lines, 5 octagons.
uniform int pattern_shape = 5;

// Number of pattern cells across the screen. Higher values make smaller, denser shapes.
uniform float pattern_scale : hint_range(2.0, 80.0) = 24.0;

// Base size of each pattern shape inside its cell.
uniform float pattern_size : hint_range(0.01, 0.5) = 0.13;

// Edge softness of each pattern shape.
uniform float pattern_softness : hint_range(0.001, 0.2) = 0.035;

// Overall visibility of the pattern.
uniform float pattern_alpha : hint_range(0.0, 1.0) = 0.18;

// Direction the pattern moves in, measured in degrees. 0 moves right, 90 moves down.
uniform float pattern_direction_degrees : hint_range(0.0, 360.0) = 25.0;

// Speed of the pattern drift.
uniform float pattern_move_speed : hint_range(0.0, 0.2) = 0.014;


// Gentle wave distortion applied to the pattern movement.
uniform float wave_strength : hint_range(0.0, 0.1) = 0.015;

// Strength of random per-shape size variation.
uniform float shape_noise_strength : hint_range(0.0, 1.0) = 0.35;

// Scale of the noise controlling shape sizes. Higher values make variation change more frequently.
uniform float shape_noise_scale : hint_range(0.1, 20.0) = 4.0;

// Speed of the animated noise controlling shape sizes.
uniform float shape_noise_speed : hint_range(0.0, 2.0) = 0.15;

// Strength of darkening around the screen edges.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

// Current screen aspect ratio. Set by the background controller script.
uniform float aspect_ratio = 1.7777778;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


vec2 random2(vec2 p) {
	p = vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	);
	
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}


float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float a = dot(random2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
	float b = dot(random2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(random2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(random2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}


float dot_shape(vec2 f, float used_size) {
	float d = length(f);
	return 1.0 - smoothstep(used_size, used_size + pattern_softness, d);
}


float diamond_shape(vec2 f, float used_size) {
	float d = abs(f.x) + abs(f.y);
	return 1.0 - smoothstep(used_size, used_size + pattern_softness, d);
}


float square_shape(vec2 f, float used_size) {
	float d = max(abs(f.x), abs(f.y));
	return 1.0 - smoothstep(used_size, used_size + pattern_softness, d);
}


float hex_shape(vec2 f, float used_size) {
	vec2 q = abs(f);
	float d = max(q.x * 0.8660254 + q.y * 0.5, q.y);
	return 1.0 - smoothstep(used_size, used_size + pattern_softness, d);
}


float octagon_shape(vec2 f, float used_size) {
	vec2 q = abs(f);
	float d = max(max(q.x, q.y), (q.x + q.y) * 0.70710678);
	return 1.0 - smoothstep(used_size, used_size + pattern_softness, d);
}


float diagonal_line_shape(vec2 p, float used_size) {
	float line_width = used_size * 0.12;
	float d = abs(fract((p.x + p.y) * 0.5) - 0.5);
	return 1.0 - smoothstep(line_width, line_width + pattern_softness, d);
}


float get_pattern_mask(vec2 p, vec2 f, float used_size) {
	if (pattern_shape == 0) {
		return dot_shape(f, used_size);
	}
	
	if (pattern_shape == 1) {
		return diamond_shape(f, used_size);
	}
	
	if (pattern_shape == 2) {
		return square_shape(f, used_size);
	}
	
	if (pattern_shape == 3) {
		return hex_shape(f, used_size);
	}
	
	if (pattern_shape == 4) {
		return diagonal_line_shape(p, used_size);
	}
	
	if (pattern_shape == 5) {
		return octagon_shape(f, used_size);
	}
	
	return dot_shape(f, used_size);
}


void fragment() {
	vec2 uv = UV;
	vec2 aspect_uv = vec2(uv.x * aspect_ratio, uv.y);
	vec2 centered = vec2((uv.x - 0.5) * aspect_ratio, uv.y - 0.5);
	
	vec4 base_color = mix(top_color, bottom_color, uv.y);
	
	float accent_distance = distance(uv, accent_position);
	float accent_mask = 1.0 - smoothstep(0.0, accent_radius, accent_distance);
	base_color = mix(base_color, accent_color, accent_mask * accent_strength);
	
	float second_accent_distance = distance(uv, second_accent_position);
	float second_accent_mask = 1.0 - smoothstep(0.0, second_accent_radius, second_accent_distance);
	base_color = mix(base_color, second_accent_color, second_accent_mask * second_accent_strength);
	
	vec2 pattern_uv = aspect_uv * pattern_scale;
	float pattern_direction_radians = pattern_direction_degrees * 0.01745329252;
	vec2 pattern_direction = vec2(cos(pattern_direction_radians), sin(pattern_direction_radians));
	pattern_uv -= pattern_direction * pattern_move_speed * TIME * pattern_scale;
	pattern_uv.x += sin((uv.y + TIME * 0.025) * TAU * 2.0) * wave_strength * pattern_scale;
	pattern_uv.y += cos((uv.x + TIME * 0.018) * TAU * 2.0) * wave_strength * pattern_scale;
	
	vec2 cell = floor(pattern_uv);
	vec2 f = fract(pattern_uv) - 0.5;
	
	float size_noise = noise2d((cell / max(shape_noise_scale, 0.001)) + TIME * shape_noise_speed);
	float size_multiplier = mix(1.0 - shape_noise_strength, 1.0 + shape_noise_strength, size_noise);
	float used_pattern_size = pattern_size * size_multiplier;
	
	float pattern_mask = get_pattern_mask(pattern_uv, f, used_pattern_size);
	float random_fade = mix(0.35, 1.0, hash21(cell));
	pattern_mask *= random_fade;
	
	vec3 final_rgb = base_color.rgb;
	final_rgb += pattern_color.rgb * pattern_mask * pattern_alpha;
	
	float vignette_distance = length(centered);
	float vignette_mask = smoothstep(0.25, 0.9, vignette_distance);
	final_rgb = mix(final_rgb, vignette_color.rgb, vignette_mask * vignette_strength * vignette_color.a);
	
	COLOR = vec4(final_rgb, 1.0);
}