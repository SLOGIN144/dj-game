--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Blockouts = require(Shared.Config.Blockouts)
local PlotLayout = require(Shared.Config.PlotLayout)
local PlotSpace = require(Shared.Util.PlotSpace)
local T = require(script.Parent.TestUtil)

-- How far a venue's world reaches from its origin along X: its widest shell part (the sea).
local function venueReach(locationId: string): number
	local reach = 0
	for _, spec in Blockouts[locationId].shell do
		reach = math.max(reach, math.abs(spec.offset.X) + spec.size.X / 2)
	end
	return reach
end

return {
	["the dorm is a floor behind the door, only Ibiza is reached by the jet"] = function()
		T.equal(PlotSpace.isVenue("dorm"), true)
		T.equal(PlotSpace.isDoor("dorm"), true)
		T.equal(PlotSpace.isVenue("club"), false)
		T.equal(PlotSpace.isDoor("club"), false)
		T.equal(PlotSpace.isVenue("ibiza"), true)
		T.equal(PlotSpace.isDoor("ibiza"), false)
		T.equal(PlotSpace.isVenue(nil), false)
		T.equal(PlotSpace.isDoor(nil), false)
	end,

	["while away at Ibiza, the street keeps the club up"] = function()
		T.equal(PlotSpace.showcaseFor("ibiza"), "club")
		T.equal(PlotSpace.showcaseFor("dorm"), nil, "nothing before the first location")
	end,

	["a venue sets its own layout; a floor behind the door has an arrival spot and an exit"] = function()
		local ibiza = PlotSpace.layout("ibiza")
		T.equal(ibiza, Blockouts.ibiza.layout)
		T.truthy(ibiza.jet ~= nil, "Ibiza has a jet back to the street")
		local dorm = PlotSpace.layout("dorm")
		T.equal(dorm, Blockouts.dorm.layout)
		T.truthy(dorm.exit ~= nil and dorm.jet == nil, "a door floor has an exit, not a jet")
		local club = PlotSpace.layout("club")
		T.equal(club.register, PlotLayout.register)
		T.equal(#club.buttonSlots, #PlotLayout.buttonSlots)
	end,

	["venues never overlap each other or reach the street"] = function()
		local reach = venueReach("ibiza")
		local spacing = PlotLayout.venues.spacing.Magnitude
		T.truthy(spacing >= 2 * reach, string.format("spacing %d, reach %d", spacing, reach))
		local first = PlotSpace.venueOrigin(1).Position
		-- The street and its skyline stay within a few hundred studs of the world's origin.
		T.truthy(first.Magnitude - reach > 1000, "the first venue is far from the street")
		local last = PlotSpace.venueOrigin(6).Position
		T.truthy(last.Magnitude < 20000, "even the sixth venue stays where physics is precise")
		T.truthy(Balance.World.plotCount <= 6, "a venue for every plot")
	end,

	["a location covers its own space size"] = function()
		T.equal(PlotSpace.size("ibiza"), Vector3.new(140, 60, 140))
		T.equal(PlotSpace.size(nil), PlotLayout.size, "a free plot covers the plot")
	end,
}
