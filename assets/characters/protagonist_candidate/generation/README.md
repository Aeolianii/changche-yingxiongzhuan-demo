# Young naval protagonist candidate

## Frame contract

- Final frames: `../standard/{idle,walk}/{down,left,right,up}/1.png..4.png`
- Frame size: 64×64 RGBA
- Direction order in sheets: down, left, right, up
- Visible subject height: 46–50 px (mean 48.81 px)
- Shared foot baseline: y=63
- Runtime scaling: none; use nearest-neighbor filtering

## Character prompt summary

Young clean-shaven Chinese naval commander, black traditional topknot, dark indigo and blue-gray light armor, muted teal sleeves, aged-brass fittings, short vermilion shoulder cape/scarf, dark boots, and a sheathed Chinese yanling saber. Avoid gray hair, beard, European armor, samurai armor, and oversized fantasy armor.

The walk and idle source sheets were generated as separate 4×4 sheets on flat `#FF00FF`, with rows down/left/right/up and four animation frames per row. The local sprite processor removed the chroma background, extracted and normalized frames, and produced transparent sheets and metadata. Final frames received a deterministic +6 px vertical alignment so their feet match the existing project protagonist at y=63.
