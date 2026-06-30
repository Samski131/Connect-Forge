shader_type canvas_item;

// Main fill colour of the slot.
uniform vec4 base_color : source_color = vec4(0.08, 0.34, 0.18, 1.0);

// Colour blended in when the slot is a valid placement edge.
uniform vec4 highlight_color : source_color = vec4(0.18, 0.9, 0.95, 1.0);

// Colour blended in when the slot is hovered.
uniform vec4 hover_color : source_color = vec4(0.55, 1.0, 0.75, 1.0);

// Bright colour used for the inner rim glow.
uniform vec4 rim_color : source_color = vec4(0.75, 1.0, 0.9, 1.0);

// 0 normal, 1 highlighted by gravity/placement, 2 hovered.
uniform int visual_state = 0;

// How strongly the highlight colour replaces the normal colour.
uniform float highlight_mix : hint_range(0.0, 1.0) = 0.82;

// How strongly the hover colour replaces the normal colour.
uniform float hover_mix : hint_range(0.0, 1.0) = 0.92;

// Strength of the soft inner rim.
uniform float rim_strength : hint_range(0.0, 1.0) = 0.28;

// Extra rim strength added when the slot is highlighted or hovered.
uniform float active_rim_boost : hint_range(0.0, 1.0) = 0.48;

// How far inward the rim reaches.
uniform float rim_size : hint_range(0.0, 0.5) = 0.22;

// Softness of the inner rim.
uniform float rim_softness : hint_range(0.001, 0.5) = 0.22;

// Strength of the animated pulse on highlighted or hovered slots.
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.18;

// Speed of the animated pulse.
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.4;

// Darkening in the centre of the slot, giving it recessed depth.
uniform float centre_depth_strength : hint_range(0.0, 1.0) = 0.28;

// Size of the central recessed area.
uniform float centre_depth_size : hint_range(0.0, 1.0) = 0.42;

// Softness of the central recessed area.
uniform float centre_depth_softness : hint_range(0.001, 1.0) = 0.38;

// Subtle lower shading amount.
uniform float vertical_shade_strength : hint_range(0.0, 1.0) = 0.18;

// How octagonal the depth shape is. Lower is softer/rounder, higher is sharper.
uniform float octagon_corner_strength : hint_range(0.0, 1.0) = 0.7;


float get_soft_octagon_distance(vec2 uv) {
	vec2 centered = abs((uv - vec2(0.5, 0.5)) * 2.0);
	float square_distance = max(centered.x, centered.y);
	float diagonal_distance = (centered.x + centered.y) * 0.70710678;
	return mix(square_distance, max(square_distance, diagonal_distance), octagon_corner_strength);
}


void fragment() {
	vec2 uv = UV;
	float shape_distance = get_soft_octagon_distance(uv);
	
	vec4 used_color = base_color;
	
	if (visual_state == 1) {
		used_color = mix(base_color, highlight_color, highlight_mix);
	}
	
	if (visual_state == 2) {
		used_color = mix(base_color, hover_color, hover_mix);
	}
	
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float active_amount = 0.0;
	
	if (visual_state > 0) {
		active_amount = 1.0;
	}
	
	float rim_start = 1.0 - rim_size;
	float rim_mask = smoothstep(rim_start, rim_start + rim_softness, shape_distance);
	float centre_mask = 1.0 - smoothstep(centre_depth_size, centre_depth_size + centre_depth_softness, shape_distance);
	
	float used_rim_strength = rim_strength + active_rim_boost * active_amount;
	float active_pulse = pulse * pulse_strength * active_amount;
	
	vec3 final_rgb = used_color.rgb;
	final_rgb = mix(final_rgb, rim_color.rgb, rim_mask * used_rim_strength);
	final_rgb += rim_color.rgb * rim_mask * active_pulse;
	final_rgb = mix(final_rgb, final_rgb * 0.68, centre_mask * centre_depth_strength);
	final_rgb = mix(final_rgb, final_rgb * 0.82, uv.y * vertical_shade_strength);
	
	if (visual_state == 1) {
		final_rgb += highlight_color.rgb * 0.08;
	}
	
	if (visual_state == 2) {
		final_rgb += hover_color.rgb * 0.12;
	}
	
	COLOR = vec4(final_rgb, used_color.a);
}