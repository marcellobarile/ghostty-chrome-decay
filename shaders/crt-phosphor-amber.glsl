// Amber phosphor CRT shader for Ghostty (P3 amber, IBM 3270 / Hercules mono)
// Effects: scanlines, bloom/glow, curvature, vignette, phosphor persistence (ghost), flicker, chromatic noise
// Tune constants in TUNING block to taste

// ─── TUNING ──────────────────────────────────────────
#define CURVATURE        0.005   // barrel distortion (0 = flat)
#define SCANLINE_STRENGTH 0.25  // 0..1
#define SCANLINE_COUNT   1.0    // multiplier on res.y
#define BLOOM_STRENGTH   0.7   // glow intensity
#define BLOOM_RADIUS     2.5    // px
#define GHOST_STRENGTH   0.22   // phosphor persistence amount
#define GHOST_OFFSET     0.0018 // horizontal trail
#define FLICKER_STRENGTH 0.035
#define NOISE_STRENGTH   0.025
#define VIGNETTE_STRENGTH 0.15
#define PHOSPHOR_TINT    vec3(1.00, 0.69, 0.00) // P3 amber (~#ffb000)
#define BRIGHTNESS       2
// ─────────────────────────────────────────────────────

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 curveUV(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = uv.yx * uv.yx * CURVATURE;
    uv += uv * offset;
    return uv * 0.5 + 0.5;
}

vec3 sampleBloom(sampler2D tex, vec2 uv, vec2 px) {
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 off = vec2(x, y) * px * BLOOM_RADIUS;
            float w = exp(-(x*x + y*y) * 0.25);
            sum += texture(iChannel0, uv + off).rgb * w;
            total += w;
        }
    }
    return sum / total;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 cuv = curveUV(uv);

    // Off-screen mask after curvature
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec2 px = 1.0 / iResolution.xy;

    // Base sample
    vec3 base = texture(iChannel0, cuv).rgb;

    // Phosphor ghost — horizontal trail (slow decay)
    vec3 ghost = vec3(0.0);
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 1.0, 0.0)).rgb * 0.5;
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 2.0, 0.0)).rgb * 0.3;
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 3.0, 0.0)).rgb * 0.2;
    base = max(base, ghost * GHOST_STRENGTH);

    // Bloom
    vec3 bloom = sampleBloom(iChannel0, cuv, px);
    bloom = max(bloom - 0.15, 0.0);
    base += bloom * BLOOM_STRENGTH;

    // Convert luminance to amber phosphor tint
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 color = PHOSPHOR_TINT * lum;

    // Preserve highlights
    color = mix(color, base, 0.15);

    // Scanlines
    float scan = sin(cuv.y * iResolution.y * SCANLINE_COUNT * 3.14159) * 0.5 + 0.5;
    color *= 1.0 - SCANLINE_STRENGTH * (1.0 - scan);

    // Vertical phosphor mask (RGB stripe simulation, biased to R+G for amber)
    float vstripe = mod(fragCoord.x, 3.0);
    if (vstripe < 1.0)      color *= vec3(1.00, 0.97, 0.92);
    else if (vstripe < 2.0) color *= vec3(1.00, 0.95, 0.90);
    else                    color *= vec3(1.00, 0.93, 0.88);

    // Flicker — fast CRT-style mains hum
    float fast = 0.035 * (hash(vec2(iTime * 55.0, 1.0)) - 0.5);
    float hum  = 0.02 * sin(iTime * 60.0);
    float flicker = 1.0 + fast + hum;
    color *= flicker;

    // Noise grain
    float n = hash(fragCoord.xy + iTime * 60.0) - 0.5;
    color += n * NOISE_STRENGTH;

    // Vignette
    vec2 vig = cuv * (1.0 - cuv.yx);
    float vmask = vig.x * vig.y * 15.0;
    vmask = pow(vmask, VIGNETTE_STRENGTH);
    color *= vmask;

    // Brightness + soft clamp
    color *= BRIGHTNESS;
    color = color / (1.0 + color * 0.3);

    fragColor = vec4(color, 1.0);
}
