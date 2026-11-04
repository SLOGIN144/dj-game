--!strict
-- Server entry point: builds the street, then starts the services and hands out plots.

local Decks = require(script.Parent.Services.Decks)
local Economy = require(script.Parent.Services.Economy)
local Music = require(script.Parent.Services.Music)
local Plots = require(script.Parent.Services.Plots)
local Shop = require(script.Parent.Services.Shop)

local plots = Plots.build()
Economy.start(plots)
Shop.start()
Music.start()
Decks.start()
Plots.start(function(state)
	Shop.refresh(state)
	Music.begin(state)
end, function(state)
	Music.stop(state.plot)
end)
