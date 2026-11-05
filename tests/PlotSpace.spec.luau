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
	["only Ibiza is built away from the street"] = function()
		T.equal(PlotSpace.isVenue("dorm"), false)
		T.equal(PlotSpace.isVenue("club"), false)
		T.equal(PlotSpace.isVenue("ibiza"), true)
		T.equal(PlotSpace.isVenue(nil), false)
	end,

	["while away at Ibiza, the street keeps the club up"] = function()
		T.equal(PlotSpace.showcaseFor("ibiza"), "club")
		T.equal(PlotSpace.showcaseFor("dorm"), nil, "nothing before the first location")
	end,

	["a venue sets its own layout, the plot locations use the plot's"] = function()
		local ibiza = PlotSpace.layout("ibiza")
		T.equal(ibiza, Blockouts.ibiza.layout)
		local dorm = PlotSpace.layout("dorm")
		T.equal(dorm.register, PlotLayout.register)
		T.equal(#dorm.buttonSlots, #PlotLayout.buttonSlots)
		T.truthy(ibiza.jet ~= nil, "Ibiza has a jet back to the street")
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
