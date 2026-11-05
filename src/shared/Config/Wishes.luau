--!strict
-- What a guest can wish for (docs: guests with wishes). One guest at a time shows a speech bubble;
-- the owner grants the wish just by doing the thing within the time, and the guest pays a tip.
-- The server decides which wish is possible and when it's done (Services/Wishes); the client only
-- draws the bubble. Tuning numbers are in Balance.Wishes.

export type Wish = {
	text: string, -- what the bubble says
	line: string, -- what the guest shouts when it's granted (shown with the tip)
}

local Wishes: { [string]: Wish } = {
	-- Catch a drop (a Perfect or Good press at the decks).
	drop = { text = "Drop it!", line = "That drop!" },
	-- Buy a track in the track shop.
	track = { text = "New tune!", line = "New tune, yes!" },
	-- Get another item built (order, carry it in, place it).
	order = { text = "More stuff!", line = "Now it's a party!" },
	-- Collect the cash from the register once it has filled a little.
	collect = { text = "Cash out!", line = "Treat yourself!" },
}

return Wishes
