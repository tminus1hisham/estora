# Mall brand mark

Three piers, two arches: the colonnade every retail arcade is built from.

The mark says *many tenants under one roof* rather than *a door*, which is what
the platform actually is. The centre pier is wider than the outer two and
carries the brass — the load-bearing column the tenancies on either side rest
against.

It replaces the earlier arch-and-open-door mark, which carried four ideas and
four colours in a square that is usually 24 px wide.

## Construction

Everything is normalised to a 512 artboard. The same numbers appear in the SVG
masters, `lib/components/app_brand_mark.dart`, the Android vector drawables and
`tool/generate_brand_assets.ps1` — change one and change all five.

| Member | Value |
| --- | --- |
| Tile corner radius | 112 (21.875%) |
| Arcade bounds | x 92–420, y 118–394 |
| Outer piers | 48 wide |
| Centre pier | 64 wide, x 224–288 |
| Bays | 84 wide, radius 42 |
| Springing line | y 220 |
| Arch crown | y 178 |

The bays are the widest members on purpose: they are the first thing to close
up as the icon shrinks, so they get the room.

## Palette

| Role | Hex | Token |
| --- | --- | --- |
| Arcade | `#0A1A30` | `AppPalette.navy900` |
| Centre pier | `#B9842E` | `AppPalette.brass500` |
| Tile | `#FFFEFB` → `#FAF8F3` → `#F3F0E9` | `stone0` → `stone50` → `stone100` |
| Reversed arcade | `#FAF8F3` | `AppPalette.stone50` |
| Reversed centre pier | `#D6B477` | `AppPalette.brass300` |

Azure is no longer in the mark. It earns its keep as the app's interactive
colour, and a third hue in the icon only made the other two quieter.

Brass at the mid weight, not the pale one: `brass300` on cream reads as a
smudge, and the reversed mark takes `brass300` for the same reason in the other
direction.

## Rules

- The mark does not invert with the theme. `AppBrandMark` draws the stone tile
  on every surface in the app, light or dark, and matches the launcher icon
  exactly. Use `tenant_portal_symbol_inverse.svg` only for collateral printed
  on navy, never in-app.
- The tile's stone gradient is the one permitted gradient, and it is three
  stops across five points of lightness. It should be invisible as an effect.
  No gradients on the arcade or the pier, and no bevels, shadows, textures or
  metallic fills anywhere.
- Do not pre-round the exported launcher PNGs. They stay square and full-bleed;
  every platform applies its own mask, and a baked-in corner shows as a seam
  inside it. The rounded tile appears only in the SVG masters, the launch
  images and `AppBrandMark`.
- Clear space is one outer pier — 48 units, 9.4% of the artboard — on all four
  sides.

## Sizes

The mark holds down to about 24 px. Below that the piers fall under two pixels
and it reads as a dark tile with a gold column: still recognisable, no longer an
arcade. That is the known cost of choosing an arcade over a single shape, and
the reason the centre pier is the accent — it is the last part of the mark
still legible at 16 px.

`web/favicon.svg` carries the vector, so browsers that support it never hit
the raster floor.

## Master assets

- `assets/branding/tenant_portal_mark.svg` — primary app-icon mark on the stone tile
- `assets/branding/tenant_portal_symbol.svg` — background-free symbol for stone surfaces
- `assets/branding/tenant_portal_symbol_inverse.svg` — porcelain and brass, for navy surfaces

## Regenerating platform assets

From the project root on Windows:

```powershell
& .\tool\generate_brand_assets.ps1
```

The generator writes Android, iOS, macOS, web, launch, maskable and Windows
icon variants from the same normalised geometry.

The Android adaptive-icon foreground and monochrome layers are hand-authored
vectors rather than generator output, and draw the arcade at 0.76 scale so it
survives a circular launcher mask. The adaptive background is
`tenant_portal_icon_background` in `android/app/src/main/res/values/brand_colors.xml`.
