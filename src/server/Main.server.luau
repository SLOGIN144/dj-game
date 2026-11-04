--!strict
-- Server entry point: builds the street, then starts the services and hands out plots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Decks = require(script.Parent.Services.Decks)
local Economy = require(script.Parent.Services.Economy)
local Events = require(script.Parent.Services.Events)
local Goals = require(script.Parent.Services.Goals)
local Music = require(script.Parent.Services.Music)
local Plots = require(script.Parent.Services.Plots)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Services.Shop)
local TrackShop = require(script.Parent.Services.TrackShop)

Remotes.createAll() -- before anything: clients wait for every remote when they start
local plots = Plots.build()
Economy.start(plots)
Shop.start()
Music.start()
Decks.start()
TrackShop.start()
Events.start()
Goals.start()
Plots.start(function(state)
	Shop.refresh(state)
	Music.begin(state)
	Events.begin(state)
	Goals.begin(state)
end, function(state)
	Events.stop(state)
	Music.stop(state.plot)
end)
