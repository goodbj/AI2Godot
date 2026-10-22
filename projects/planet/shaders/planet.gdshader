shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ---- Shape ----
uniform vec3 seed_offset = vec3(0.0, 0.0, 0.0);
uniform float noise_scale = 2.2;
uniform int octaves = 6;
uniform float sea_level = 0.50;

// ---- Evolution ----
// 0 Asteroid, 1 Meteor, 2 Planet, 3 Star, 4 White Dwarf, 5 Black Hole
uniform int stage = 2;
uniform float black_hole_amount : hint_range(0.0, 1.0) = 0.0;
uniform float spin = 0.0;

// ---- Palette ----
uniform vec3 ocean_deep : source_color = vec3(0.02, 0.06, 0.18);
uniform vec3 ocean_shallow : source_color = vec3(0.06, 0.25, 0.45);
uniform vec3 sand : source_color = vec3(0.72, 0.66, 0.45);
uniform vec3 grass : source_color = vec3(0.16, 0.38, 0.16);
uniform vec3 forest : source_color = vec3(0.08, 0.22, 0.10);
uniform vec3 rock : source_color = vec3(0.34, 0.30, 0.27);
uniform vec3 snow : source_color = vec3(0.92, 0.94, 0.97);

// ---- Atmosphere ----
uniform vec3 atmosphere_color : source_color = vec3(0.30, 0.60, 1.00);
uniform float atmosphere_strength = 1.8;
uniform float rim_power = 3.0;

// ---- Surface ----
uniform float roughness_land = 0.92;
uniform float roughness_water = 0.12;
uniform float bump_strength = 0.35;

uniform vec3 accretion_color : source_color = vec3(1.0, 0.45, 0.10);

// ---- Rival tinting ----
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float heat : hint_range(0.0, 1.0) = 0.0;

varying vec3 obj_pos;

vec3 hash3(vec3 p) {
	p = vec3(
		dot(p, vec3(127.1, 311.7, 74.7)),
		dot(p, vec3(269.5, 183.3, 246.1)),
		dot(p, vec3(113.5, 271.9, 124.6))
	);
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = dot(hash3(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0));
	float n100 = dot(hash3(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0));
	float n010 = dot(hash3(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0));
	float n110 = dot(hash3(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0));
	float n001 = dot(hash3(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0));
	float n101 = dot(hash3(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0));
	float n011 = dot(hash3(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0));
	float n111 = dot(hash3(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);

	return 0.5 + 0.5 * mix(mix(nx00, nx10, u.y), mix(nx01, nx11, u.y), u.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= octaves) { break; }
		v += a * noise3(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 dir = normalize(obj_pos);
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);

	float h = fbm(dir * noise_scale + seed_offset);
	float detail = fbm(dir * noise_scale * 7.0 + seed_offset * 1.7);
	float land = smoothstep(sea_level - 0.02, sea_level + 0.02, h);

	float rim = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), rim_power);
	float rim_sharp = pow(1.0 - clamp(dot(n, view_dir), 0.0, 1.0), 2.2);

	// ================= ROCKY / PLANET (stages 0-2) =================
	vec3 col = mix(ocean_deep, ocean_shallow, smoothstep(sea_level - 0.12, sea_level, h));
	col = mix(col, sand, smoothstep(sea_level, sea_level + 0.035, h));
	col = mix(col, grass, smoothstep(sea_level + 0.03, sea_level + 0.10, h));
	col = mix(col, forest, smoothstep(sea_level + 0.09, sea_level + 0.18, h));
	col = mix(col, rock, smoothstep(sea_level + 0.20, sea_level + 0.30, h));
	col = mix(col, snow, smoothstep(sea_level + 0.30, sea_level + 0.38, h));
	col *= 0.88 + 0.24 * detail;

	// Asteroid / Meteor: bare rock, no oceans, cratered look
	float craters = fbm(dir * 14.0 + seed_offset * 2.3);
	float crater_ring = smoothstep(0.42, 0.48, craters) * smoothstep(0.62, 0.52, craters);
	vec3 rock_col = mix(vec3(0.13, 0.11, 0.10), vec3(0.38, 0.34, 0.30), h * 0.7 + detail * 0.3);
	rock_col *= 1.0 - 0.45 * crater_ring;
	float rocky = (stage <= 0) ? 1.0 : (stage == 1 ? 0.65 : 0.0);
	col = mix(col, rock_col, rocky);

	// ================= STAR (stage 3) =================
	float granule = fbm(dir * 26.0 + vec3(spin * 0.8, spin * 0.3, 0.0));
	float cell = fbm(dir * 11.0 - vec3(0.0, spin * 0.5, 0.0));
	vec3 star_col = mix(vec3(0.85, 0.22, 0.02), vec3(1.0, 0.72, 0.20), cell);
	star_col = mix(star_col, vec3(1.0, 0.97, 0.80), granule * 0.65);
	// Limb darkening so the disc reads as a sphere, not a flat cutout
	float limb = pow(clamp(dot(n, view_dir), 0.0, 1.0), 0.45);
	star_col *= 0.55 + 0.75 * limb;

	// ================= WHITE DWARF (stage 4) =================
	float dwarf_noise = fbm(dir * 18.0 + vec3(0.0, spin * 0.4, 0.0));
	vec3 dwarf_col = mix(vec3(0.45, 0.68, 1.0), vec3(1.0, 1.0, 1.0), dwarf_noise);
	float dwarf_limb = pow(clamp(dot(n, view_dir), 0.0, 1.0), 0.35);
	dwarf_col *= 0.8 + 0.9 * dwarf_limb;

	// ================= BLACK HOLE (stage 5) =================
	float swirl = fbm(vec3(dir.x * 5.0, dir.z * 5.0, spin + dir.y * 1.5));
	float band = smoothstep(0.25, 1.0, rim_sharp);
	float disk = band * (0.45 + 1.1 * swirl);
	vec3 bh_emission = accretion_color * disk * 5.0
		+ vec3(0.55, 0.75, 1.0) * pow(rim_sharp, 7.0) * 2.5;

	// ================= COMBINE =================
	vec3 emission = atmosphere_color * rim * atmosphere_strength + col * 0.015;
	vec3 albedo = col;
	float rough = mix(roughness_water, roughness_land, land);
	float spec = mix(0.65, 0.18, land);

	if (stage == 3) {
		albedo = vec3(0.0);
		emission = star_col * 0.85 + vec3(1.0, 0.45, 0.08) * pow(rim, 1.6) * 2.2;
		rough = 1.0;
	} else if (stage == 4) {
		albedo = vec3(0.02);
		emission = dwarf_col * 0.95 + vec3(0.45, 0.7, 1.0) * pow(rim, 2.2) * 2.4;
		rough = 0.6;
	}

	float bh = black_hole_amount;
	albedo = mix(albedo, vec3(0.004, 0.004, 0.006), bh);
	emission = mix(emission, bh_emission, bh);

	// Rival bodies: tinted, with an angry glow that intensifies when hunting.
	albedo *= tint;
	emission *= tint;
	emission += tint * heat * (0.25 + 0.55 * rim);

	ALBEDO = albedo;
	ROUGHNESS = mix(rough, 0.25, bh);
	SPECULAR = mix(spec, 0.9, bh);
	METALLIC = 0.0;
	EMISSION = emission;
}
