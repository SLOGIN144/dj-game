# Phone orders and truck delivery: the dorm slice

2026-11-05. Implements `docs/superpowers/specs/2026-11-05-truck-delivery-design.md` for the dorm only,
with a bigger dorm room laid out after Filip's new reference (the dorm model sheet). The other rooms
follow the same pattern once Filip has played this one.

## Decisions from Filip (2026-11-05, in chat)

- Build order: the dorm to the end first (room, phone, truck, boxes, outlines), then the other rooms.
- Items: the reference lists, plus extra items where the room needs them. Costs and incomes still
  come from `Pricing` (the GDD's curve), not from the numbers painted on the reference images.
- Models: blockouts from code are fine for the prototype; real models come later.
- A fifth location from the neon-club reference sits between the house party and the underground
  club. It is built after the dorm.
- UI references for the phone come later, so the phone is a plain functional panel for now.

## What gets built

1. **Pure logic.** `Economy/Orders` (cart checks, delivery time, box states) with specs;
   `Balance.Delivery`; two remotes (`PlaceOrder`, `OrderResult`).
2. **The dorm room.** 36 x 32 studs instead of 24 x 20, a front with two low wall stubs, the building
   behind it moved back. 16 items (the reference's 12 plus lamp, disco ball, party lights, neon).
   `Blockout.placements` marks where an item goes when it needs a spot other than its own box.
3. **The delivery.** `World/Truck`, `Services/Delivery`, boxes on the pavement, outlines in the room,
   `Shop` split into charge and place. The floor pads go; Move On stays a pad.
4. **Client.** `UI/Phone` (HUD icon, P, list, Order), `PromptFilter` shows pick-up and place prompts
   only to the owner and only when they fit what is being carried, `Guide` points at boxes and
   outlines, Max's lines now talk about the phone.
5. **Checks.** Specs for `Orders`, `docs/studio-checklist.md` section for the truck, a Studio
   playtest through the MCP.

## Where this differs from the spec

- **Carrying is server-side.** The box is welded to the character on the server, so everyone sees it
  and no client `Carry` controller is needed.
- **No refund code on leaving.** `PlayerState.snapshot` saves `cash + inFlight`, so cash paid for
  boxes not yet placed is never lost, also on a crash or an autosave mid-order. This answers the
  spec's open question without a schema change.
- **Pick-up and place use ProximityPrompts** (like the speaker's Fix prompt), so there is no extra
  remote for them. The server checks owner, state and distance on every trigger.
- **The shelf is mirrored as a Player attribute** (`Shelf`: the next visible item ids), so the phone
  needs no copy of the unlock rules.

## Not in this slice

The other rooms, the neon club, phone UI art, truck sounds, imported truck model, simulation updates
(`tools/cloud/simulate.luau` still buys through `Shop.buy`, which stays as an instant purchase for
tests and the Studio shortcuts; Lune is not installed on this machine, so it could not be run).
