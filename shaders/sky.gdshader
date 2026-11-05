shader_type sky;
// NYX-7 sky: deep gradient with a warm horizon glow, drifting high cloud banks, a starfield, two moons
// and an aurora band toward the Spire. Exterior = violet dusk; Extraction = the same sky turned red by the storm.
uniform vec3 zenith = vec3(0.01, 0.008, 0.03);
uniform vec3 horizon = vec3(0.16, 0.09, 0.22);
uniform vec3 glow_col = vec3(0.55, 0.22, 0.45);
uniform vec3 cloud_col = vec3(0.09, 0.06, 0.13);
uniform vec3 aurora_col = vec3(0.35, 0.12, 0.6);
uniform vec3 moon1_dir = vec3(-0.45, 0.42, -0.78);
uniform vec3 moon2_dir = vec3(0.62, 0.22, -0.75);
uniform float aurora = 1.0;
uniform float clouds = 0.7;
uniform float stars = 1.0;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * vnoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

vec3 moon(vec3 dir, vec3 mdir, float size, vec3 col) {
	float d = dot(dir, normalize(mdir));
	float disc = smoothstep(cos(size), cos(size * 0.92), d);
	float halo = pow(max(d, 0.0), 220.0) * 0.6 + pow(max(d, 0.0), 30.0) * 0.08;
	vec3 q = dir * 90.0;
	float n = hash(floor(q)) * 0.25;
	return col * (disc * (0.85 - n) + halo);
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(max(h, 0.0), 0.5));
	// warm glow hugging the horizon, strongest toward the Spire (-Z)
	float toward = 0.55 + 0.45 * smoothstep(0.2, -0.9, d.z);
	col += glow_col * exp(-max(h, 0.0) * 9.0) * 0.45 * toward;
	if (h < 0.0) col = mix(horizon * 0.55, horizon * 0.25, clamp(-h * 4.0, 0.0, 1.0));
	// stars (hidden behind clouds)
	vec3 sp = d * 260.0;
	float s = hash(floor(sp));
	float star = step(0.9965, s) * smoothstep(0.0, 0.2, h) * (0.6 + 0.4 * sin(TIME * 2.0 + s * 100.0)) * stars;
	// high cloud banks projected on a dome
	float cl = 0.0;
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * 1.6 + vec2(TIME * 0.004, TIME * 0.002);
		float n = fbm(uv);
		cl = smoothstep(0.48, 0.78, n) * clouds * smoothstep(0.0, 0.12, h);
		vec3 lit = cloud_col + glow_col * 0.25 * exp(-h * 5.0) * toward;
		col = mix(col, lit, cl * 0.85);
	}
	col += vec3(star) * 1.4 * (1.0 - cl);
	float band = exp(-pow((h - 0.18 - 0.05 * sin(d.x * 6.0 + TIME * 0.05)) * 9.0, 2.0)) * smoothstep(-0.2, -0.9, d.z);
	col += aurora_col * band * 0.35 * aurora * (1.0 - cl * 0.6);
	col += moon(d, moon1_dir, 0.06, vec3(1.0, 0.92, 0.86) * 1.6) * (1.0 - cl * 0.8);
	col += moon(d, moon2_dir, 0.03, vec3(0.75, 0.6, 1.0) * 1.4) * (1.0 - cl * 0.8);
	COLOR = col;
}
