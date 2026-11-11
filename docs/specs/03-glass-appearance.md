# 03 · Glass and appearance

## Purpose
This spec defines how the notch surface is drawn: solid black or "clear glass". The glass
must look like Apple's clearest Liquid Glass. The panel stays black across the camera band,
opens into a clear lens towards the bottom, and its edges visibly bend the desktop behind
it.

## Behaviour

### Styles
- **Glass** (default) or **Black**, chosen in Settings → Notch.
- When the system *Reduce Transparency* setting is on, Black is always used.

### The compact notch is always solid black
- Compact and idle shapes are pure black with **no outline and no rim**, whatever the style.
- Glass and outlines appear only when content is **expanded**.
- Switching between compact and expanded cross-fades a black cover over the surface.
- The surface element itself stays alive while the shape resizes. Re-creating it during the
  animation causes flicker.

### Glass, expanded (layers from back to front)
1. **Progressive blur of the desktop.** No blur above the clear-start line, then a blur that
   ramps up to ≈ 3 pt radius by the clear line and holds to the bottom.
2. **Apple's lensing glass** in its fully clear variant. Its rounded corners refract the
   blurred desktop, so moving content behind the panel bends at the edges. It must ignore the
   system-wide glass tint control (the *Liquid Glass* slider in System Settings); ordinary
   glass gets frosted by that slider. Only the bottom corners should show lensing: the top
   edge is extended above the screen so it has no visible lens.
3. **White tint** at 2 %.
4. **Vertical dimming**, defined by *transmission*, the share of the desktop that shows
   through, at height fraction *y* (top = 0, bottom = 1):
   - fully black from the top down to y = 0.44;
   - a smooth S-curve opening (smoothstep) from y = 0.44 to y = 0.71;
   - from 0.71 to the bottom, transmission = transparency × 0.95, leaving a residual 5 % dim.
   - These bands come from 0.49, 0.76 and 15 % with a +10 % clarity boost applied:
     boost × 0.5 is subtracted from both band edges, and the boost is subtracted from the
     residual dim.
5. **Rim:** a 0.5 pt white outline at 32 % opacity.
6. **Content outline:** the content's outline colour at the user's outline width. Both rim
   and outline fade in from y = 0.44 to y = 0.71, so nothing is outlined across the camera
   band.

### Fallback
- When the lensing glass or the progressive blur is not available on the system, use the
  standard SwiftUI clear glass with the same dimming underneath.
- In this case an opaque black cap covers the top down to just past y = 0.44, fading out
  over ≈ 0.12 of the height.

### Black, expanded
- Solid black, plus the content outline at the user's width.

### Shadow
- A soft shadow, black at 20 % with a 20 pt radius, lies **outside** the outline only.
- It must not sit behind the glass: a shadow under a transparent surface greys it out. Draw
  it as a separate sibling with the interior cut away.
- It fades with the content.

### Shape
- **Notch screens:** the outline follows the hardware notch. The top corners flare outward
  into the menu bar with the top radius, and the bottom corners round with the bottom radius.
- **Island mode:** a rounded rectangle with the island radius ([01](01-notch-shell.md)).
- **Expanded pages:**
  - bottom radius 25 pt;
  - inner content margin 20 pt plus the top radius on each side, or 20 pt in island mode;
  - 12 pt spacing between blocks.

## Settings
| Setting | Default | Effect |
|---|---|---|
| Background style | Glass | Glass / Black |
| Glass transparency | 1.0 (range 0–1) | Scales transmission below the black band |
| Alert duration scale | 1.0 | Not shown in Settings; internal or debug only |
| Show outline | On | Content outline on expanded content |
| Outline width | 2.5 pt (1–3) | |
| Outline opacity | 0.6 (0–0.6, shown as 0–100 %) | Multiplies the content's own outline colour alpha |
| Settings window appearance | System | System / light / dark; applies to the settings window only |

## Edge cases
- **Reduce Transparency switched on at runtime:** switch to Black immediately.
- **A very bright desktop:** the dimming keeps the top 44 % black, so content stays readable.
- **The system Liquid Glass slider at "tinted":** the glass must not turn milky.
- **Island mode:** the dimming bands still apply. The glass needs no upward extension because
  the pill has four rounded corners.

## Acceptance checks
1. Compact and idle notches are pure black. Zoomed in, no light pixel shows on the outline.
2. Over a moving, striped test window, the expanded glass bends the stripes at its bottom
   corners. The top 44 % stays black.
3. Changing System Settings → Liquid Glass to its most tinted value does not visibly frost
   the expanded notch.
4. Glass transparency 0 makes the expanded panel black. At 1 the bottom is ≈ 95 % clear.
5. With *Reduce Transparency* on, the expanded panel is solid black.
6. No grey haze shows inside the expanded panel from the shadow.
