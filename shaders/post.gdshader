shader_type canvas_item;
// Screen-space finishing: vignette, film grain, low-health desaturation/pulse, damage flash, slight
// chromatic aberration when hurt. Cheap enough for mobile (one texture read per channel).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float damage = 0.0;
uniform float low_health = 0.0;
uniform float vignette = 0.32;
uniform float grain = 0.035;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float ca = 0.0015 + damage * 0.006 + low_health * 0.003;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), low_health * 0.55);
	float pulse = 0.5 + 0.5 * sin(TIME * 5.5);
	float r = length(c * vec2(1.0, 0.85));
	float v = smoothstep(0.38, 0.95, r);
	col *= 1.0 - v * (vignette + low_health * 0.35);
	vec3 red = vec3(0.55, 0.02, 0.02);
	col = mix(col, red, clamp(v * (low_health * (0.35 + 0.25 * pulse) + damage * 0.9), 0.0, 0.85));
	col += (hash(uv * 893.0 + fract(TIME) * 37.0) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
