// Shared 3-band cel lighting (spec §12.1, §15.12): banded diffuse with a
// shadow tint, crisp specular highlight.
void cc_toon_light(vec3 n, vec3 l, vec3 v, float atten, vec3 light_color, float spec_strength,
		inout vec3 diffuse, inout vec3 specular) {
	float ndl = clamp(dot(n, l), 0.0, 1.0) * atten;
	float band = ndl > 0.5 ? 1.0 : (ndl > 0.08 ? 0.55 : 0.0);
	diffuse += band * light_color / PI;
	float s = pow(clamp(dot(reflect(-l, n), v), 0.0, 1.0), 24.0);
	specular += step(0.8, s) * spec_strength * light_color * atten;
}
