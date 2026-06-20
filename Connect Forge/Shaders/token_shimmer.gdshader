shader_type canvas_item;

uniform float shimmer_progress = -1.0;
uniform vec2 token_center_global = vec2(0.0, 0.0);

uniform float shimmer_span = 280.0;
uniform float shimmer_width = 45.0;
uniform float shimmer_strength = 0.75;
uniform vec2 shimmer_direction = vec2(0.707, -0.707);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec4 output_color = base;

	if (base.a > 0.001 && shimmer_progress >= 0.0) {
		vec2 dir = normalize(shimmer_direction);

		float current_axis_pos = dot(world_pos - token_center_global, dir);
		float shimmer_axis_pos = mix(-shimmer_span, shimmer_span, shimmer_progress);
		float distance_from_band = abs(current_axis_pos - shimmer_axis_pos);

		float soft_band = smoothstep(shimmer_width, 0.0, distance_from_band);
		float sharp_core = smoothstep(shimmer_width * 0.22, 0.0, distance_from_band);

		vec3 silver = vec3(0.95, 0.98, 1.0);

		vec3 final_rgb = mix(base.rgb, silver, soft_band * shimmer_strength);
		final_rgb += silver * sharp_core * shimmer_strength * 0.25;

		output_color = vec4(final_rgb, base.a);
	}

	COLOR = output_color;
}