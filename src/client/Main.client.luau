--!strict
-- Client entry point. Starts the HUD and the other client controllers.

local DebugOverlay = require(script.Parent.UI.DebugOverlay)
local Hud = require(script.Parent.UI.Hud)
local PadLabels = require(script.Parent.UI.PadLabels)
local PlotMixes = require(script.Parent.Controllers.PlotMixes)
local PlotMusic = require(script.Parent.Controllers.PlotMusic)

Hud.start()
PadLabels.start()
PlotMixes.start()
PlotMusic.start()
DebugOverlay.start()
