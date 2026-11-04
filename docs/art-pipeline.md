# Art pipeline: from blockout to real models

Everything in the world is built from code at server start: plain parts called blockouts. They
fix sizes and positions, so gameplay works now. Real art replaces them one model at a time, with
no code changes.

## The model sheets

Every model the game needs has a card on the Claude Design canvas:
**https://claude.ai/artifact/VjmvYsj7Rbrkyvphc6WshY**

The boards are Street, Dorm, House party, Club, Ibiza and Characters. Each card gives:

- the model's **id** (the name to give it in Studio);
- its **size in studs** and where its **pivot** goes;
- its colours and materials;
- a prompt for an image or 3D generator.

The concept images in `docs/concept/` set the mood. The cards set the sizes.

## Where imported models go

Put models in **ServerStorage › Art › <folder>**, each named after what it replaces:

| Folder | Model name | Replaces | Pivot at |
| --- | --- | --- | --- |
| `dorm`, `house`, `club`, `ibiza` | an item id, e.g. `club_bar` | that item's blockout parts | the bottom centre of the item's blockout box |
| `dorm`, `house`, `club`, `ibiza` | `Shell` | the location's room (walls, floor, fixed decor) | the location's origin: the plot's centre, or for Ibiza the venue's origin |
| `street` | a prop id: `street_tree`, `street_bench`, `street_bin`, `street_billboard`, `street_gate`, `street_jet` | that street prop | as the prop's card says |
| `street` | `building_<stage>`: `building_free`, `building_dorm`, `building_house`, `building_club`, `building_ibiza` | the plot's building at that stage | the bottom centre of its front face |

The server copies the model, anchors it and strips any scripts. `World/Art.luau` does this, and
`Shared/Util/Bounds.luau` works out the blockout box.

## Keeping the light show and the effects working

The client drives parts by their **attributes**, so imported models need them too:

| Attribute | Value | What happens |
| --- | --- | --- |
| `LightRole` | `led`, `speaker`, `spot`, `disco`, `screen` or `neon` | The light show (`Controllers/LightShow`) colours and pulses the part on the beat. A `spot` with a `Beam` inside sweeps it. |
| `Fx` | `confetti`, `co2` or `fireworks` | On every drop (`Controllers/Effects`), confetti, a CO2 jet or a firework comes out of the top of the part. |

Lights (a `PointLight` or `SpotLight`) and `Beam`s inside a part are driven too.

## Rules for the art

- **Content rules** win over the concept images: no alcohol (soda, juice and water only), no real
  brands or logos, no real DJs.
- Smooth, rounded, stylized shapes, lit realistically: one dominant colour per location, with
  white beams as accents.
- Keep part counts low. All six plots are on screen together, and phones must hold 30 FPS.
- The player-facing side is the front: on the street that's −Z, with +X on the left as seen
  from the street.
- Characters and guests need R15 rigs and animation IDs from Filip before they replace the
  part-built figures (`Controllers/Guests`, `Controllers/StarDjView`, `World/Figures`).
