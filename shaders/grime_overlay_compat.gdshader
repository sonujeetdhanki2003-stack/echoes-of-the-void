shader_type spatial;
// COMPATIBILITY-renderer variant of grime_overlay.gdshader (see the note at the bottom). M2 realism pass: a multiply overlay (GeometryInstance3D.material_overlay) laid over the station's kit and props.
// World-space triplanar grime: darker dirt band at the base of walls, water/leak streaks running down walls,
// blotchy wear on floors. Multiply blend keeps the underlying PBR lighting and only darkens.
render_mode blend_mix, unshaded, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.62, 0.56, 0.5);
uniform float strength = 0.55;
uniform float floor_y = 0.0;
uniform float base_h = 0.75;
uniform float streaks = 1.0;
uniform float scale = 0.16;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z + 1e-4);
	float n = texture(noise, wp.zy * scale).r * bw.x
	        + texture(noise, wp.xz * scale).r * bw.y
	        + texture(noise, wp.xy * scale).r * bw.z;
	float fine = texture(noise, (wp.xz + wp.zy) * scale * 4.3).r;
	float wall = 1.0 - bw.y;
	// vertical streaks: stretch the noise along Y on walls
	float s = texture(noise, vec2((wp.x + wp.z) * 1.1, wp.y * 0.06)).r;
	float streak = smoothstep(0.62, 0.86, s) * wall * streaks;
	float h = mod(wp.y - floor_y, 4.0);   // decks repeat roughly every 4 m in the station
	float base = (1.0 - smoothstep(0.0, base_h, h)) * wall;
	float blot = smoothstep(0.5, 0.82, n) * (0.55 + 0.45 * fine);
	float g = clamp(base * 0.85 + blot * 0.7 + streak * 0.6, 0.0, 1.0) * strength;
	// Compatibility renderer (web): blend_mul overlays come out black there regardless of the colour, so the same multiply
	// is expressed as an alpha mix toward a near-black dirt colour: result = d*(1-a) + c*a ~ d*mix(1, tint, g)
	vec3 f = mix(vec3(1.0), tint, g);
	float avg = (f.r + f.g + f.b) / 3.0;
	ALBEDO = tint * 0.1;
	ALPHA = clamp((1.0 - avg) / 0.9, 0.0, 1.0);
}
