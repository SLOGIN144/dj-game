--!strict
-- Where a plot's current location is built: on the plot by the street, or at the plot's own
-- venue far from it (Ibiza, reached by the jet). The server mirrors a venue's origin on the plot
-- as its "SpaceOrigin" attribute. Everything that places or looks for a location's things (the
-- room, buttons, register, guests, decks, lights) goes through here, so it works the same in both.

local Blockouts = require(script.Parent.Parent.Config.Blockouts)
local Locations = require(script.Parent.Parent.Config.Locations)
local PlotArea = require(script.Parent.PlotArea)
local PlotLayout = require(script.Parent.Parent.Config.PlotLayout)
local Types = require(script.Parent.Parent.Types)

local PlotSpace = {}

-- Where the buttons, the register and the spawn go, relative to the location's origin, and for a
-- venue, its jet back to the street.
export type Layout = { buttonSlots: { Vector3 }, register: Vector3, spawn: Vector3, jet: Vector3? }

function PlotSpace.location(locationId: string?): Types.Location?
	for _, location in Locations do
		if location.id == locationId then
			return location
		end
	end
	return nil
end

-- The plot's current location, or nil while the plot is free.
function PlotSpace.locationId(plot: Model): string?
	local id = plot:GetAttribute("LocationId")
	return if typeof(id) == "string" then id else nil
end

-- Whether the location is built in a venue of its own rather than on the plot.
function PlotSpace.isVenue(locationId: string?): boolean
	local location = PlotSpace.location(locationId)
	return location ~= nil and location.space == "venue"
end

-- Where the venue of the plot with this index goes: far from the street, one beside the other.
function PlotSpace.venueOrigin(plotIndex: number): CFrame
	return CFrame.new(PlotLayout.venues.start + PlotLayout.venues.spacing * (plotIndex - 1))
end

-- The origin of the plot's current location: its venue's, or the plot's own.
function PlotSpace.origin(plot: Model): CFrame
	local venue = plot:GetAttribute("SpaceOrigin")
	return if typeof(venue) == "CFrame" then venue else plot:GetPivot()
end

-- Whether the plot's location is away at its venue right now.
function PlotSpace.away(plot: Model): boolean
	return typeof(plot:GetAttribute("SpaceOrigin")) == "CFrame"
end

function PlotSpace.layout(locationId: string?): Layout
	local blockout = if locationId then Blockouts[locationId] else nil
	if blockout and blockout.layout then
		return blockout.layout
	end
	return { buttonSlots = PlotLayout.buttonSlots, register = PlotLayout.register, spawn = PlotLayout.spawn }
end

-- The footprint (X by Z) the location covers around its origin.
function PlotSpace.size(locationId: string?): Vector3
	local location = PlotSpace.location(locationId)
	return if location then location.spaceSize else PlotLayout.size
end

-- Studs from `position` to the plot's current location: 0 inside it.
function PlotSpace.distance(plot: Model, position: Vector3): number
	return PlotArea.distance(PlotSpace.origin(plot), position, PlotSpace.size(PlotSpace.locationId(plot)))
end

function PlotSpace.contains(plot: Model, position: Vector3): boolean
	return PlotSpace.distance(plot, position) <= 0
end

-- Studs to the nearest place the plot's mix plays: its location, and while that is away at the
-- venue, the plot itself too (the building on the street keeps the last club open).
function PlotSpace.hearingDistance(plot: Model, position: Vector3): number
	local distance = PlotSpace.distance(plot, position)
	if PlotSpace.away(plot) then
		distance = math.min(distance, PlotArea.distance(plot:GetPivot(), position))
	end
	return distance
end

-- The last location before `locationId` that is built on the plot: what the street shows while
-- the owner is away at a venue.
function PlotSpace.showcaseFor(locationId: string): string?
	local last = nil
	for _, location in Locations do
		if location.id == locationId then
			return last
		end
		if location.space == "plot" then
			last = location.id
		end
	end
	return nil
end

return PlotSpace
