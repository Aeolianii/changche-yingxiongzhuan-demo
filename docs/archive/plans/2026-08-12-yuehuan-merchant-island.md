# Yuehuan Merchant Island Implementation Plan

> **For agentic workers:** Execute inline in this session. Follow `docs-first-game-dev`, `godot-editor-first`, `test-driven-development`, `imagegen`, and `generate2dsprite`; each behavior-changing task starts with a failing Godot test.

**Goal:** Replace the direct-open merchant harbor menu with an explorable island where two visible merchants open role-specific shops through dialogue.

**Architecture:** Keep the current economy and travel services unchanged. Convert the existing scene path into a world scene with a single generated background, hand-authored coarse collision, one player, two declarative merchant NPCs, a state-owning harbor controller, and one reusable role-filtered shop overlay.

**Tech Stack:** Godot 4.7, GDScript, generated PNG background/sprites, existing `GameState`/`TradeService` APIs.

## Global Constraints

- Preserve the existing scene path and save V2 schema.
- Preserve all current prices, item sources, blueprint rules, fleet limit 10, free repair assumption, and unlimited warehouse.
- No interiors, complex collision, dynamic prices, schedules, new products, equipment, repair, consumables, or paid content.
- Use generated bitmap art for the requested map and merchants; do not substitute code-drawn placeholders.

---

### Task 1: Art production and import

**Files:**
- Create: `assets/yuehuan_merchant_island/backgrounds/yuehuan_merchant_island_v1.png`
- Create: `assets/yuehuan_merchant_island/characters/liang_trader_v1.png`
- Create: `assets/yuehuan_merchant_island/characters/shen_shipwright_v1.png`
- Modify: `docs/assets/generated-backgrounds.md`

- [ ] Generate one 1536×1024 island background matching the documented composition and project art direction.
- [ ] Generate each merchant as a separate 2.5-to-3-head-tall chibi pixel map sprite on flat chroma-key background; reject realistic adult proportions.
- [ ] Remove chroma-key backgrounds, validate alpha and silhouette, and copy final assets into the project.
- [ ] Import with nearest filtering and visually inspect scale against the existing protagonist.

### Task 2: Test the island scene contract

**Files:**
- Create: `tests/test_yuehuan_merchant_island.gd`
- Modify: `tests/verify_merged_project.ps1`

**Interfaces:**
- Consumes: scene path `res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn`.
- Produces: assertions for world nodes, merchant roles, initial exploration state, shop state transitions, and return request.

- [ ] Write tests that expect background/player/collision, merchant roles `goods` and `shipyard`, no shop visible on ready, and role-specific UI contents.
- [ ] Run the test and record the expected failure against the old direct-open UI scene.

### Task 3: Merchant world interactions

**Files:**
- Create: `scripts/yuehuan_merchant/merchant_npc.gd`
- Create: `scripts/yuehuan_merchant/merchant_shop_overlay.gd`
- Create: `scenes/yuehuan_merchant_harbor/merchant_shop_overlay.tscn`
- Modify: `scripts/yuehuan_merchant_harbor.gd`
- Modify: `scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn`

**Interfaces:**
- `MerchantNpc.merchant_id: String`, `display_name: String`, `shop_role: String`, `dialogue_text: String`.
- `MerchantShopOverlay.open_shop(role: String, title: String) -> void` and signal `closed`.
- Harbor test helpers: `open_merchant_dialogue_for_test(id)`, `choose_trade_for_test()`, `close_shop_for_test()`, `active_shop_role_for_test()`.

- [ ] Build the single-image world, player, camera, two merchants, dock, triggers, prompt, dialogue host and coarse collision.
- [ ] Implement the four-state interaction controller and nearest trigger selection.
- [ ] Implement the role-filtered overlay by extracting/reusing the current trade UI behavior.
- [ ] Run the focused test until green, then run existing economy and harbor regression tests.

### Task 4: Visual and runtime acceptance

**Files:**
- Create: `tests/capture_yuehuan_merchant_island.gd`
- Update: `docs/changes/CHG-20260812-yuehuan-merchant-island.md`

- [ ] Validate the touched scene/scripts/resources in Godot 4.7.
- [ ] Run the exact island scene and read all runtime/editor errors.
- [ ] Capture exploration, goods shop, and shipyard shop at 1344×896; inspect art scale, roads, text and clipping.
- [ ] Run with visible collision shapes and verify the dock-to-shop main route plus nearby blocked regions.
- [ ] Run the merged verification suite and all existing economy/save/harbor tests.
- [ ] Reconcile documents with actual behavior, record commands/screenshots/known limitations, and set the change status to `done` only if all acceptance checks pass.
- [ ] Launch the exact island scene in a visible Godot window for user acceptance.
