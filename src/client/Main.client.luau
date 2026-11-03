--!strict
-- Client entry point. Starts the HUD and the other client controllers.

local Hud = require(script.Parent.UI.Hud)
local PadLabels = require(script.Parent.UI.PadLabels)

Hud.start()
PadLabels.start()
