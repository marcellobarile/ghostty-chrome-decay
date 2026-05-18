// Glitch shader for Ghostty — VHS / signal-loss style
// Effects: horizontal slip lines, RGB channel split, block displacement bursts,
// scanline jitter, occasional dropouts. Layered on top of subtle CRT base.
// Tune constants in TUNING block.

// ─── TUNING ──────────────────────────────────────────
#define GLITCH_STRENGTH   1.0     // master multiplier (0 = off)
#define BURST_FREQ        0.25    // bursts per second (avg). Lower = rarer
#define BURST_DURATION    0.15     // seconds a burst lasts
#define SLIP_AMOUNT       0.045   // max horizontal displacement (uv)
#define SLIP_BANDS        90.0    // vertical resolution of slip noise
#define RGB_SPLIT_AMOUNT  0.006   // chroma offset during burst
#define BLOCK_CHANCE      0.05    // chance a horizontal band is displaced
#define DROPOUT_CHANCE    0.012   // chance of black line dropout
#define SCANLINE_STRENGTH 0.15
#define NOISE_STRENGTH    0.06
#define TINT              vec3(1.00, 0.69, 0.00) // amber to match active theme
#define TINT_MIX          0.35    // 0 = no tint, 1 = full tint
// Protected zone — band of N rows above/below the active cursor row.
// Active row is detected by scanning iChannel0 vertically for the lowest
// non-background line (heuristic for the line the user is typing on).
#define PROTECT_ROWS_ABOVE 5      // rows above cursor kept clean
#define PROTECT_ROWS_BELOW 5      // rows below cursor kept clean
#define ROW_HEIGHT_PX      30.0   // approx terminal row height in pixels (font-size 18 -> ~28-32)
#define PROTECT_RAMP_ROWS  1.5    // soft fade at edges of the band, in rows
#define SCAN_SAMPLES       24     // vertical samples used to find active row (per column)
#define SCAN_LUM_THRESHOLD 0.06   // luminance above this counts as "text"
#define SCAN_MAX_Y         0.92   // ignore top 8% (often title bar / empty)
#define FALLBACK_ACTIVE_Y  0.05   // used if no text found (idle terminal)
// ─────────────────────────────────────────────────────

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Burst envelope: pulses on every ~1/BURST_FREQ seconds, decays over BURST_DURATION
float burstEnvelope(float t) {
    float seed = floor(t * BURST_FREQ);
    float fire = step(0.5, hash(seed));
    float phase = fract(t * BURST_FREQ) / BURST_FREQ;
    float decay = exp(-phase / BURST_DURATION);
    return fire * decay;
}

// Detect the lowest non-empty row in uv coords by scanning two columns.
// Returns the smallest uv.y where luminance exceeds the background threshold,
// which approximates the cursor row in interactive terminal use. Falls back
// to FALLBACK_ACTIVE_Y when the screen appears empty (e.g. cleared terminal).
float detectActiveRow() {
    float bestY = -1.0;
    for (int i = 0; i < SCAN_SAMPLES; i++) {
        float yFrac = (float(i) + 0.5) / float(SCAN_SAMPLES) * SCAN_MAX_Y;
        vec3 sampleL = texture(iChannel0, vec2(0.05, yFrac)).rgb;
        vec3 sampleR = texture(iChannel0, vec2(0.95, yFrac)).rgb;
        vec3 sampleM = texture(iChannel0, vec2(0.50, yFrac)).rgb;
        float lum = max(max(
            dot(sampleL, vec3(0.299, 0.587, 0.114)),
            dot(sampleR, vec3(0.299, 0.587, 0.114))),
            dot(sampleM, vec3(0.299, 0.587, 0.114)));
        if (lum > SCAN_LUM_THRESHOLD && bestY < 0.0) {
            bestY = yFrac;
        }
    }
    return bestY < 0.0 ? FALLBACK_ACTIVE_Y : bestY;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float t = iTime;

    // Dynamic protected band centered on the detected active row.
    // Convert row counts to uv space using ROW_HEIGHT_PX / resolution.
    float rowH = ROW_HEIGHT_PX / iResolution.y;
    float activeY = detectActiveRow();
    float bandMin = activeY - PROTECT_ROWS_BELOW * rowH;
    float bandMax = activeY + PROTECT_ROWS_ABOVE * rowH;
    float ramp = PROTECT_RAMP_ROWS * rowH;
    // zoneMask = 1 outside the band (full glitch), 0 inside (clean), smooth ramps at edges.
    float belowBand = smoothstep(bandMin, bandMin - ramp, uv.y); // 1 when uv.y < bandMin - ramp
    float aboveBand = smoothstep(bandMax, bandMax + ramp, uv.y); // 1 when uv.y > bandMax + ramp
    float zoneMask = max(belowBand, aboveBand);

    // Pass-through in protected zone — no work, no glitch
    if (zoneMask <= 0.0) {
        fragColor = vec4(texture(iChannel0, uv).rgb, 1.0);
        return;
    }

    float burst = burstEnvelope(t) * GLITCH_STRENGTH * zoneMask;

    // Slip only during burst (no constant slip — keeps idle state clean)
    float bandY = floor(uv.y * SLIP_BANDS);
    float bandNoise = hash2(vec2(bandY, floor(t * 12.0))) - 0.5;
    float slip = bandNoise * SLIP_AMOUNT * burst * 0.6;

    // Block displacement — only some bands get hit during burst
    float blockHit = step(1.0 - BLOCK_CHANCE * burst, hash2(vec2(bandY, floor(t * 6.0))));
    slip += blockHit * (hash2(vec2(bandY, t)) - 0.5) * SLIP_AMOUNT * 4.0 * burst;

    vec2 suv = uv + vec2(slip, 0.0);
    suv = clamp(suv, vec2(0.0), vec2(1.0));

    // RGB channel split during burst
    float split = RGB_SPLIT_AMOUNT * burst;
    float r = texture(iChannel0, suv + vec2(split, 0.0)).r;
    float g = texture(iChannel0, suv).g;
    float b = texture(iChannel0, suv - vec2(split, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // Dropouts — black lines on bursts
    float dropout = step(1.0 - DROPOUT_CHANCE * burst, hash2(vec2(bandY, floor(t * 30.0))));
    color *= 1.0 - dropout;

    // Scanlines with jitter (only during burst, scaled by zone)
    float scanJitter = (hash(t * 3.0) - 0.5) * 2.0 * burst;
    float scan = sin((uv.y + scanJitter * 0.001) * iResolution.y * 3.14159) * 0.5 + 0.5;
    color *= 1.0 - SCANLINE_STRENGTH * (1.0 - scan) * zoneMask;

    // Amber tint (luminance-preserving mix), scaled by zone so protected area stays untinted
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 tinted = TINT * lum;
    color = mix(color, tinted, TINT_MIX * zoneMask);

    // Noise grain — only during burst
    float n = hash2(fragCoord.xy + t * 60.0) - 0.5;
    color += n * NOISE_STRENGTH * burst;

    // Burst flash — brief brightness spike
    color += burst * 0.08;

    fragColor = vec4(color, 1.0);
}
