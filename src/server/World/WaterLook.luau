--!strict
-- How terrain water looks: the Ibiza sea (Config/Blockouts/Ibiza) is clear Mediterranean
-- turquoise with small waves. Terrain water settings are global; only the venues have water.

local WaterLook = {}

function WaterLook.apply()
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(30, 150, 165)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
end

return WaterLook
