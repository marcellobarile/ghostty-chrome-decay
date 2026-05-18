# ghostty-chrome-decay

> *Your terminal isn't broken. It's just remembering things it shouldn't.*

A small collection of GPU shaders for [Ghostty](https://ghostty.org): VHS rot, signal loss, channel-split static, and three flavors of CRT phosphor glow — green, amber, paper-white. Stack them or run them solo. The glitch layer never touches the row you're typing on.

```
┌─────────────────────────────────────────────────┐
│ ▓▒░ chrome flakes off the bones of the grid ░▒▓ │
│ ▓▒░       and the buffer remembers           ░▒▓ │
└─────────────────────────────────────────────────┘
```

---

## What's in the box

| File                              | What it is                                                                 |
|-----------------------------------|----------------------------------------------------------------------------|
| `shaders/chrome-decay.glsl`       | The headline glitch layer — VHS slip, RGB split, dropouts, block tear.     |
| `shaders/crt-phosphor.glsl`       | P1 green phosphor CRT. Scanlines, bloom, curvature, ghost trail, flicker.  |
| `shaders/crt-phosphor-amber.glsl` | Same CRT, retuned for amber phosphor (P3-style monitors).                  |
| `shaders/crt-phosphor-paper.glsl` | Same CRT, cold paper-white phosphor for the "office terminal" look.        |

All four share the same shape: `mainImage(out fragColor, in fragCoord)`, ShaderToy-style, sampling `iChannel0` (the terminal framebuffer).

---

## chrome-decay — the glitch layer

A fragment shader painting VHS-era decay on top of the terminal framebuffer:

- **Horizontal slip lines** — bands of the buffer tear sideways during bursts.
- **RGB channel split** — chroma divorces from luma on each glitch pulse.
- **Block displacement** — random rows get yanked, like a tracking head losing the signal.
- **Dropouts** — black scanline gaps, briefly, on bursts.
- **Scanline jitter** — the grid breathes.
- **Phosphor tint** — luminance-preserving, tunable to match whichever CRT base you stack underneath.
- **Cursor-row sanctuary** — the line you're typing on (plus a configurable band above/below) stays untouched. You see clean text where you're working; everything else rots.

It runs only during bursts, not every frame, so the idle terminal looks calm. When the burst fires, the world flickers for ~150ms.

## crt-phosphor — the base CRT

Three variants, same shape, retuned palette per phosphor:

- **`crt-phosphor.glsl`** — P1 green, the classic Apple ][ / VT100 / oscilloscope look.
- **`crt-phosphor-amber.glsl`** — P3-style amber, lower eye strain, '80s mainframe vibes.
- **`crt-phosphor-paper.glsl`** — cold blue-white, late-CRT "paper-white" monitors.

Each one adds: barrel curvature, scanlines, bloom/glow, phosphor persistence (ghost trail), flicker, vignette, chromatic noise. All knobs live in a `TUNING` block at the top of the file.

---

## Quickstart

### 1. Get Ghostty

Ghostty is a fast, GPU-accelerated terminal emulator by Mitchell Hashimoto. Grab it:

- Official site: <https://ghostty.org>
- Downloads: <https://ghostty.org/download>
- Source: <https://github.com/ghostty-org/ghostty>

macOS users can also `brew install --cask ghostty`.

You need Ghostty **1.0 or newer** for the `custom-shader` config key.

### 2. Drop the shaders in

Clone this repo somewhere stable:

```sh
git clone https://github.com/marcellobarile/ghostty-chrome-decay.git ~/src/ghostty-chrome-decay
```

Or copy the shaders into your Ghostty config dir:

```sh
mkdir -p ~/.config/ghostty/shaders
cp shaders/*.glsl ~/.config/ghostty/shaders/
```

### 3. Wire it into Ghostty

Edit `~/.config/ghostty/config`. Pick one of the recipes below.

**Just the glitch, no CRT base:**

```
custom-shader = shaders/chrome-decay.glsl
custom-shader-animation = true
```

**Green CRT only (no glitch):**

```
custom-shader = shaders/crt-phosphor.glsl
custom-shader-animation = true
```

**Amber CRT + glitch (the headline combo):**

```
custom-shader = shaders/crt-phosphor-amber.glsl
custom-shader = shaders/chrome-decay.glsl
custom-shader-animation = true
```

**Paper-white CRT + glitch:**

```
custom-shader = shaders/crt-phosphor-paper.glsl
custom-shader = shaders/chrome-decay.glsl
custom-shader-animation = true
```

Ghostty supports stacking — each `custom-shader` line is another pass, applied in order. Glitch goes **after** the CRT base so the tearing paints on top of the curvature and bloom.

Paths are relative to the Ghostty config directory (`~/.config/ghostty/`). Use an absolute path if you prefer keeping the shaders inside the cloned repo:

```
custom-shader = /Users/marcellobarile/src/ghostty-chrome-decay/shaders/chrome-decay.glsl
```

### 4. Reload

`Cmd+Shift+,` reloads the config. If nothing changes, fully quit Ghostty (`Cmd+Q`) and reopen — shader caches can be sticky.

---

## Tuning

### chrome-decay.glsl

Open it and scroll to the `TUNING` block. Every dial is a `#define`:

| Constant            | What it controls                                         |
|---------------------|----------------------------------------------------------|
| `GLITCH_STRENGTH`   | Master multiplier. `0.0` = off, `1.0` = stock, `2.0` = unhinged. |
| `BURST_FREQ`        | Bursts per second (average). Lower = rarer.              |
| `BURST_DURATION`    | How long a burst decays, in seconds.                     |
| `SLIP_AMOUNT`       | Max horizontal slip in UV space.                         |
| `RGB_SPLIT_AMOUNT`  | Chroma divorce distance during bursts.                   |
| `BLOCK_CHANCE`      | Probability a band gets yanked during a burst.           |
| `DROPOUT_CHANCE`    | Probability of a black-line dropout.                     |
| `SCANLINE_STRENGTH` | Depth of the scanline dark stripes.                      |
| `NOISE_STRENGTH`    | Burst grain.                                             |
| `TINT`              | Phosphor color. `(1.0, 0.69, 0.0)` is amber. Try `(0.0, 1.0, 0.4)` for green, `(0.9, 0.95, 1.0)` for cold paper-white. **Match your CRT base.** |
| `TINT_MIX`          | `0.0` = no tint, `1.0` = full phosphor wash.             |
| `PROTECT_ROWS_ABOVE` / `PROTECT_ROWS_BELOW` | Rows around the cursor kept clean.       |
| `ROW_HEIGHT_PX`     | Approx pixel height of a terminal row. Match your font size. |

**Subtle:**

```glsl
#define GLITCH_STRENGTH   0.4
#define BURST_FREQ        0.1
#define RGB_SPLIT_AMOUNT  0.002
```

**Deranged:**

```glsl
#define GLITCH_STRENGTH   1.6
#define BURST_FREQ        0.8
#define BLOCK_CHANCE      0.15
#define DROPOUT_CHANCE    0.04
```

### crt-phosphor*.glsl

Same idea — `TUNING` block at the top:

| Constant            | What it controls                                                |
|---------------------|-----------------------------------------------------------------|
| `CURVATURE`         | Barrel distortion. `0.0` = flat panel, `0.02` = vintage CRT.    |
| `SCANLINE_STRENGTH` | Depth of horizontal scanlines.                                  |
| `SCANLINE_COUNT`    | Scanline density (multiplier on vertical resolution).           |
| `BLOOM_STRENGTH`    | Glow intensity around bright pixels.                            |
| `BLOOM_RADIUS`      | Glow spread in pixels.                                          |
| `GHOST_STRENGTH`    | Phosphor persistence (trailing ghost amount).                   |
| `GHOST_OFFSET`      | Horizontal direction of the trail.                              |
| `FLICKER_STRENGTH`  | AC-line flicker amount.                                         |
| `NOISE_STRENGTH`    | Chromatic noise grain.                                          |
| `VIGNETTE_STRENGTH` | Edge darkening.                                                 |
| `PHOSPHOR_TINT`     | The phosphor color itself. Each variant ships a sane default.   |
| `BRIGHTNESS`        | Output gain.                                                    |

To make your own custom phosphor color: duplicate `crt-phosphor.glsl`, change `PHOSPHOR_TINT`, and stack it like the others.

---

## How the cursor sanctuary works

`chrome-decay` scans the framebuffer vertically across three columns (left / middle / right) and finds the lowest row that contains text-colored pixels — the heuristic for the active line. A band of `PROTECT_ROWS_ABOVE + PROTECT_ROWS_BELOW` rows around it is fed through untouched, with a soft `PROTECT_RAMP_ROWS` fade at the edges so the transition doesn't look like a hard mask.

If the terminal is empty (cleared screen), it falls back to `FALLBACK_ACTIVE_Y` — the top of the screen — so an idle prompt stays clean too.

This is a heuristic, not magic. If you're running something that paints text on every row (e.g. `top`, `htop`), the sanctuary defaults to the topmost row. Tune `SCAN_LUM_THRESHOLD` if your theme has unusual contrast.

---

## Troubleshooting

**Nothing happens after reload.**
Path likely unresolved. Switch to an absolute path. `~` is not always expanded inside Ghostty's config parser.

**Screen is normal but I expect chaos.**
Drop in a smoke-test shader to confirm the slot is live:

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(sin(iTime)*0.5+0.5, 0.0, 0.0, 1.0);
}
```

Screen pulses red? Shader pipeline works — your tuning is just under the perception threshold. Screen is unchanged? Path or config key is wrong.

**Compile errors are silent.**
On macOS, tail the system log while reloading:

```sh
log stream --predicate 'process == "ghostty"' --level debug
```

Look for shader compile diagnostics.

**Multiple `custom-shader` lines.**
Ghostty supports stacking shaders — each line adds another pass. Glitch belongs **after** the CRT base. Order matters.

---

## License

MIT. Fork it, mutate it, tune it past sanity, ship it under another alias. The chrome decays either way.

---

*"The grid isn't a window. It's a wound that won't close."*
