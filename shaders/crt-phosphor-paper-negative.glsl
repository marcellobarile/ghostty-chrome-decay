// Paper-negative phosphor CRT shader for Ghostty — inverted paper-white
// Bright background, dark text, warm ivory tint. CRT effects on top.
// Effects: scanlines, bloom/glow, curvature, vignette, phosphor persistence (ghost), flicker, chromatic noise
// Tune constants in TUNING block to taste

// ─── TUNING ──────────────────────────────────────────
#define CURVATURE        0.005   // barrel distortion (0 = flat)
#define SCANLINE_STRENGTH 0.18  // 0..1 — lighter on bright bg
#define SCANLINE_COUNT   1.0    // multiplier on res.y
#define BLOOM_STRENGTH   0.25   // low — dark text on bright bg blooms little
#define BLOOM_RADIUS     2.5    // px
#define GHOST_STRENGTH   0.10   // ink-bleeding trail
#define GHOST_OFFSET     0.0018 // horizontal trail
#define FLICKER_STRENGTH 0.012  // low — flicker pops on bright bg
#define NOISE_STRENGTH   0.018
#define VIGNETTE_STRENGTH 0.07  // low — dark edges read hard on bright field
#define PHOSPHOR_TINT    vec3(0.98, 0.96, 0.88) // warm ivory/cream
#define BRIGHTNESS       1.0
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

    // Phosphor ghost — horizontal trail (slow decay), computed pre-inversion
    // so bright text in original domain bleeds as a dark shadow post-invert
    vec3 ghost = vec3(0.0);
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 1.0, 0.0)).rgb * 0.5;
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 2.0, 0.0)).rgb * 0.3;
    ghost += texture(iChannel0, cuv - vec2(GHOST_OFFSET * 3.0, 0.0)).rgb * 0.2;
    base = max(base, ghost * GHOST_STRENGTH);

    // Bloom (pre-inversion)
    vec3 bloom = sampleBloom(iChannel0, cuv, px);
    bloom = max(bloom - 0.15, 0.0);
    base += bloom * BLOOM_STRENGTH;

    // Invert — dark bg + bright text becomes bright bg + dark text
    base = 1.0 - base;

    // Convert luminance to warm ivory phosphor tint
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 color = PHOSPHOR_TINT * lum;

    // Preserve highlights
    color = mix(color, base, 0.15);

    // Scanlines — dark lines on bright field
    float scan = sin(cuv.y * iResolution.y * SCANLINE_COUNT * 3.14159) * 0.5 + 0.5;
    color *= 1.0 - SCANLINE_STRENGTH * (1.0 - scan);

    // Vertical phosphor mask (neutral warm stripes)
    float vstripe = mod(fragCoord.x, 3.0);
    if (vstripe < 1.0)      color *= vec3(0.98, 0.97, 0.94);
    else if (vstripe < 2.0) color *= vec3(0.97, 0.96, 0.93);
    else                    color *= vec3(0.96, 0.95, 0.92);

    // Flicker
    float fast = FLICKER_STRENGTH * (hash(vec2(iTime * 55.0, 1.0)) - 0.5);
    float hum  = (FLICKER_STRENGTH * 0.65) * sin(iTime * 60.0);
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
