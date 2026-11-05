# The growing building: floors behind a door

2026-11-05. Idea by Filip, shaped in chat the same day. Status: design only, not built. Branch: `prototype`.
Follows `2026-11-05-truck-delivery-design.md`; the dorm already buys through the phone and the truck.

## Why

Filip played the dorm and said the open room looks like an unfinished box: he expected an apartment in a
building, a place that grows into a club. He wants old rooms to stay and pay while the new one builds on
top. This also settles the GDD's open question "How doors work".

## The player's flow

1. **The street shows a building**, the plot's facade, which already grows with the career
   (`Config/Buildings`). It has a door with an **Enter** prompt. No room stands open on the plot any more.
2. **Enter** (anyone, not only the owner): the screen fades and the player is moved to the owner's **newest
   floor**, a closed room (four walls, no ceiling, so the camera still sees in) in the plot's own space far
   from the street. An **Exit** door in the room takes anyone back to the street, in front of that building.
3. **Visitors** hear the music, see the guests and the lights and can walk around. They cannot order,
   collect, play the decks, book DJs or place anything: every owner prompt already carries the owner's id
   and the server checks it.
4. **Move On:** when every item of the floor is placed, the Move On pad (inside the room) builds the next
   floor. The facade grows on the street, the old interior is removed and sealed for good, and the owner
   appears in the new empty floor. Nobody can ever enter an old floor again.
5. **Ibiza** stays the jet trip at the end of the street. The stack is dorm, house party, neon club,
   underground club.

## Money

Sealed floors keep paying, and the numbers do not change: the income curve already starts each location at
the previous one's end income (`Pricing`, `carryOver`), and gear multiplies the whole plot's income. The
design only describes that as "the old floors still pay". No schema change: a save still holds the current
location and its bought items.

## The rooms

Every converted floor is a closed room built in a venue space, using what Ibiza already has: one space per
plot (`PlotSpace.venueOrigin`), a teleport with a fade (`Services/Travel`) and a layout of its own (spawn,
register, entrance). Each location switches to `space = "venue"` when its room is converted. Locations not
yet converted stay open rooms on the plot; the code already handles a mix, so Move On from a closed dorm to
an open house party works until that one is converted too.

## Delivery with doors

- The phone works from anywhere. The truck always stops on the street and leaves the boxes on the pavement
  (decided with Filip: the truck is seen, and the door becomes part of the loop).
- The owner carries a box through the Enter door; the weld holds through the teleport (to be tested). The
  place prompt works only at the outline inside the floor.
- Dying still puts the box back on its pavement slot.
- `Delivery.order` no longer refuses while the owner is away from the street.

## Visitors and safety

- The Enter prompt on a free plot is off. When an owner leaves, every visitor is moved out to the street
  before the floor is cleared.
- Visitors respawn at their own plot's street spawn. A server has at most 6 players, so at most 5 visitors.
- The destination is streamed in before the move (`Travel.place`), as for the jet.

## What changes in the code

| Part | Change |
| --- | --- |
| `Config/Locations`, `Config/Blockouts/Dorm` | the dorm becomes `space = "venue"` and a closed room with an Exit door and a layout (spawn, entrance) |
| `World/PlotView` | the street plot keeps only the facade and gets the Enter door; the room is built at the venue; Exit door and Move On pad inside |
| `Services/Travel` | Enter and Exit moves for any player, using the owner's current floor; visitors ejected when an owner leaves |
| `Services/Delivery` | orders allowed while away; nothing else changes |
| `Services/Plots` | spawn on the street in front of the door; eject visitors before clearing |
| `UI/Guide`, `Config/Goals` | the arrow and Max point at the door; his lines say "go inside" |
| `Config/Buildings` | one facade per stage, keeps growing; old floors read as lit windows |

## Testing

- Pure spec for the door rules (who may enter, free plot refused, which floor).
- Studio checks in `docs/studio-checklist.md`: enter and exit as owner and as a second player, a visitor
  cannot use owner prompts, a box survives the door, Move On seals the old floor, an owner leaving ejects
  visitors, music heard by a visitor. A two-player test needs Test › Clients and Servers.
- Touch cannot be tested from here.

## Not in this design

- Guests with wishes and DJ crates with mystery and legendary DJs: separate designs (below).
- The phone's look (Filip's UI references come later) and real models.
- Visiting someone's older floors (sealed on purpose).

## Follow-up designs, in order

1. **Guests with wishes:** individual guests ask for a track, a soda or a spot to dance; granting it pays a
   tip or a combo. Small, independent of the building.
2. **DJ crates:** DJs are hatched from crates (common, mystery, legendary) instead of booked for cash. Needs a
   save version 3 for owned DJs and Filip's OK, and the GDD's rule holds: crates open only with in-game cash
   or earned keys, never Robux; any odds shown to players.

## Open for Filip

- Whether the exit door puts a visitor in front of the building they left (proposed) or at their own plot.
- Whether old floors should show something more than lit windows from the street (guests as silhouettes).
