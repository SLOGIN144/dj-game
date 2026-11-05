# Phone orders and truck delivery — design

2026-11-05. Idea by Filip; the design below was approved in chat the same day.
Status: design only, not built. Branch: `prototype`.

## Why

Today a purchase is stepping on a pad on the floor. Filip wants something more fun and different: order on a phone, a truck brings the order, and the player has to collect it and place it. The change serves the pillars like this:

- **Always a next step / active play:** while the truck drives, the player can catch a drop or handle an event.
- **Easy to start:** a phone menu is simpler than walking to pads, and it works better on touch.
- **Show it off:** the truck drives down the shared street, so other players see it.

## The player's flow

1. The player presses the phone icon on the HUD (P on PC, a tap on touch). A list opens with the same items that are visible as pads today (`Unlocks.visible`: the next 2–3).
2. They select up to 3 items they can afford and press **Order**. The cash is taken at once.
3. A truck drives down the street to the kerb in front of their building. The wait is about 15 s, a little longer per extra item (numbers in `Balance.Delivery`). Everyone on the street sees it.
4. The truck leaves one labelled box per item on the pavement.
5. The player picks a box up (E, or a tap on touch) and **carries one box at a time** into the room. Carrying does not change walk speed.
6. In the room, a glowing outline marks where the item goes. The player places the box there (E or a tap). The item appears with the existing build animation and sound.
7. **Income starts only when the item is placed**, not when it is ordered.

Rules around it:

- While a delivery is on its way or boxes are still unplaced, the player cannot place a new order. (Max 3 items per order, so there are never more than 3 boxes.)
- The first item of each location is free. It goes through the same order, so a new player learns the truck loop with the first click.
- The **Move on** pad stays a floor pad, as in the GDD. It is not a delivery.
- The register, the decks, events and star DJs are unchanged.

## What changes in the code

| Part | Change |
| --- | --- |
| `shared/Economy/Orders.luau` (new, pure, tested) | Validates a cart (visible, affordable, max size, no repeat), computes total cost and delivery time, and holds the order states: ordered → delivered → carried → placed. |
| `shared/Config/Balance.luau` | New `Delivery` table: base seconds, seconds per extra item, max cart size, truck speed. |
| `shared/Remotes.luau` | New remotes (names to be fixed in the plan): place an order, order progress to the owner, pick up a box, place a box. |
| `server/Services/Delivery.luau` (new) | Owns the orders. Charges on order, drives the truck, creates boxes, checks pick-up and placement, then marks the item as bought. |
| `server/Services/Shop.luau` | `Shop.buy` splits into charging (at order) and placing (at the outline). The floor pads go; the Move on pad stays. `Shop.bought` / `Shop.completed` still fire, now at placement, so goals, income and Progression keep working. |
| `server/World/PlotView.luau` | `setPads` is replaced by placement outlines and delivery boxes. `setMoveOn` and `showItem` stay. |
| `server/World/Truck.luau` (new) | Builds the truck blockout and moves it along the street to the plot's kerb and away. A marked spot for an imported model, per `docs/art-pipeline.md`. |
| `client/UI/Phone.luau` (new) | The HUD icon, the item list with check boxes, total and Order button. Works with mouse, keyboard and touch. |
| `client/Controllers/Carry.luau` (new) | Shows the box in the player's hands. |
| `client/UI/Guide.luau`, `Config/Goals.luau` | The phone icon pulses until the first order. Max's goal texts change from "step on" wording to ordering and placing. |

## Data and saving

No schema change. `boughtItems` still holds only placed items.

- If the player leaves while an order is on its way, or boxes are unplaced or carried, the paid cash is **refunded** before the record is saved. Nothing in flight is stored.
- If a server shuts down without the leave handler running, the cash is lost for that order. This is rare, and is the same exposure the register already has. (Decision for Filip: accept, or add an `orders` field in schema v3 later.)

## Safety

The server owns every step, as with all cash values:

- Only the plot's owner can order, pick up and place.
- The cart is validated against `Unlocks.canBuy` and the player's cash.
- Pick-up needs the player to be near the box; placement needs them near the outline; both are rate-limited.
- A box only becomes an item at its own outline; a box can't be moved to another plot or location.

## Pacing risk

The dorm is meant to take about 10 minutes of active play. Waiting and carrying make it longer. The mitigations are in `Balance.Delivery`: short waits, ordering up to 3 at once, and tuning after the first Studio playtest. Idle play stays about 30% slower than active play as before. If the loop feels slow, the first knobs are the base wait and the cart size.

## Testing

- **Pure specs** for `Orders` (cart validation, cost, timing, state order, refund) in `tests/`, run by `tools/cloud/check.sh`.
- **Simulation** (Lune, in `tools/cloud/`): extend it to order, deliver, carry and place an item, and to leave mid-order and check the refund.
- **Studio checklist:** new entries in `docs/studio-checklist.md` for the truck, boxes, outline, carry on touch, and a two-player check that the other player sees the truck.
- Touch cannot be tested from here; Filip checks it on a phone.

## Out of scope

Carrying several boxes at once, the truck for non-item purchases (tracks, DJ bookings, Move on), more truck types per location, truck sounds beyond one engine loop, and any change to the save schema.

## Open for Filip

- The refund-on-leave rule above (accept the rare loss, or add schema v3).
- Names for the new remotes are set in the implementation plan.
