# Tenant Portal brand mark

The mark combines three ideas in one compact architectural symbol:

- the porcelain arch represents commercial property;
- the open brass door represents a welcoming, managed space;
- the azure threshold represents secure tenant access.

The production mark is intentionally flat and geometric so it remains clear at
16 px and feels consistent with the app's restrained, premium interface.

## Master assets

- `assets/branding/tenant_portal_mark.svg` — primary app-icon mark on navy
- `assets/branding/tenant_portal_symbol.svg` — background-free symbol for navy surfaces
- `design/tenant_portal_logo_concept.png` — generated visual concept used during refinement

## Palette

| Role | Hex |
| --- | --- |
| Navy | `#0A1A30` |
| Porcelain | `#FAF8F3` |
| Brass | `#D6B477` |
| Azure | `#2078CE` |

Keep the production mark flat: no gradients, bevels, shadows, textures, or
metallic effects. Platform masks should shape the app icon; do not pre-round
the exported launcher PNGs.

## Regenerating platform assets

From the project root on Windows:

```powershell
& .\tool\generate_brand_assets.ps1
```

The generator writes Android, iOS, macOS, web, splash, maskable, and Windows
icon variants from the same normalized geometry.
