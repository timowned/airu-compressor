# Edge-gradient visual QA

Scope: the new edge lighting in the active drop target and shared analyzing panel. Existing foreground icon, prompt sizing and button behavior were kept outside this change.

## Evidence

- Source visual truth: `DesignReference/drop-edge-reference.png` (2082×1430), copied from the supplied screenshot.
- Implementation: `Tests/Screenshots/drop-edge-glow.png` (1200×664), rendered from the actual native `DropZoneView` at 600×332 points, scale 2, with the compiled asset catalog.
- Full-view comparison: `Tests/Screenshots/drop-edge-comparison.png` (1200×332; reference left, implementation right).
- Normalization: source panel bounds (107,290,1868,1034) and implementation are both reduced to 600×332. Native window chrome and surrounding annotations are excluded.
- State: file held over drop area; glow fully visible. `Tests/Screenshots/auto-analyzing.png` also verifies the same asset in the analyzing state.

## Findings

No remaining actionable P0/P1/P2 findings in the scoped edge-gradient comparison.

- Color and lighting: narrow cyan rim, blue/violet perimeter bands and a broad near-black center now closely follow the new reference. The previous warm lower-left lighting and center-heavy texture are removed. Minor differences in the locations of violet/cyan accents remain P3; this is a recreated texture, not a pixel-identical source export.
- Layout: illumination fills all four bounds, stays clipped to the rounded drop surface and fades inward without illuminating the app's header or outer background. The rim stays fixed during slow color-phase motion. Corner geometry and border layout use the existing native component.
- Typography and copy: existing system font and `Drop your files` text remain unchanged. Their slight size difference from the reference is outside the requested gradient change. The analyzing state retains its white loader and `Analyzing...` label.
- Asset quality: a dedicated 1685×934 bundled bitmap was generated from the supplied reference without its UI, text or border. Native rendering calibrates saturation to 0.65 and opacity to 0.68. No logo or prompt is baked into the background. There are no warm highlights or center graphics.
- Focused comparison: the full-view comparison clearly shows the thin rim, inward fade and color distribution on every side; no additional crop was needed for this background-only change.

## Comparison history

1. The prior glow used a cropped multicolor texture with warm lighting, which did not match the new reference (P2). Replaced it with a dedicated edge-light texture derived from the supplied reference.
2. The first comparison used the displayed preview dimensions rather than the source's full resolution. Corrected the crop to the measured 2082×1430 source before judging proportions.
3. Calibrated saturation and reduced opacity from the initial 0.72 to 0.68. The final combined capture shows the new rim and black-center proportions; residual accent placement differences are P3.

## Verification

- `bash Scripts/render-analysis.sh`: both native render checks passed (drop target and analyzing panel).
- `bash Scripts/build.sh`: release build, packaging and deep/strict signature verification passed.
- `git diff --check`: passed.
- The new asset is bundled offline. Idle app background remains solid #151515. Compression behavior did not change.
- This is a rendered native-component visual comparison. A live Finder drag gesture was not repeated in the existing user session.

## Implementation checklist

- [x] Replace the old warm/diffuse glow with the supplied reference's edge-light composition.
- [x] Preserve the dark center, rounded clipping and idle app background.
- [x] Share the texture across drop and analyzing states.
- [x] Keep motion subtle and respect Reduce Motion.
- [x] Inspect a normalized source/implementation comparison and build the final app.

final result: passed
