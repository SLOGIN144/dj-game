--!strict
-- Client entry point. Starts the HUD and the other client controllers.

local DebugOverlay = require(script.Parent.UI.DebugOverlay)
local Guests = require(script.Parent.Controllers.Guests)
local Hud = require(script.Parent.UI.Hud)
local LightShow = require(script.Parent.Controllers.LightShow)
local PadLabels = require(script.Parent.UI.PadLabels)
local PlotMixes = require(script.Parent.Controllers.PlotMixes)
local PlotMusic = require(script.Parent.Controllers.PlotMusic)

Hud.start()
PadLabels.start()
PlotMixes.start()
PlotMusic.start()
LightShow.start()
Guests.start()
DebugOverlay.start()
