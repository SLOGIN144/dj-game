--!strict
-- Server entry point: builds the street, then starts the economy, the shop and plot assignment.

local Economy = require(script.Parent.Services.Economy)
local Plots = require(script.Parent.Services.Plots)
local Shop = require(script.Parent.Services.Shop)

local plots = Plots.build()
Economy.start(plots)
Shop.start()
Plots.start(Shop.refresh)
