# CHG-20260809-sea-overworld-ship-anchor: Align stopped ship and protagonist

- Status: done
- Type: fix
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

Keep the protagonist visually attached to the same deck anchor when the sea-overworld ship switches between sailing and stopped artwork.

## Scope

- Compensate for the vertical source-pixel offset between the stopped and sailing rows of the player ship atlas.
- Keep the already-approved protagonist position unchanged.
- Add a targeted runtime assertion for ship-frame alignment across the movement-state transition.

## Non-goals

- Do not regenerate or redraw the ship or protagonist atlases.
- Do not change movement, collision, wake animation, scale, or character/ship draw order.
- Do not split the ship into foreground and background occlusion layers.

## Acceptance checks

- [x] Sailing appearance remains unchanged.
- [x] Releasing movement input aligns the stopped ship deck with the protagonist without moving the protagonist into the hull.
- [x] All four ship directions use the same verified 98-source-pixel vertical correction.
- [x] The targeted sea-overworld runtime test passes.

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scripts/sea_overworld_player.gd`, `tests/test_sea_overworld.gd`
- Constraints and risks: the atlas rows use equal frame rectangles but the visible ship art is shifted vertically by 98 source pixels; compensate the stopped ship sprite rather than moving the protagonist.

## Verification evidence

- Automated: Godot 4.7.1 windowed `res://tests/test_sea_overworld.gd` passed, including sailing position, stopped ship correction, unchanged protagonist anchor, and stopped wake state.
- Manual/in-engine: inspected fresh post-draw movement and stopped screenshots; the protagonist remains on the same deck position, the stopped frame has no wake, and neither state introduces the previous vertical separation.

## Final reconciliation

- Files changed: `scripts/sea_overworld_player.gd`, `tests/test_sea_overworld.gd`, `docs/design/sea-overworld-design.md`, and this change record.
- Documented limitations/follow-ups: foreground railing occlusion remains outside this fix; the correction depends on the current atlas's verified 98-pixel row displacement and must be recalibrated if that atlas is redrawn.
