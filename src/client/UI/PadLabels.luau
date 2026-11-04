--!strict
-- Colours the price on the player's own button pads: green when they can afford it, grey-red
-- when they can't. Only the look changes; the server decides every purchase. A new part of the
-- club pops with a sound, and the camera takes a short look at it (Controllers/Camera.peek).

local Players = game:GetService("Players")

local Camera = require(script.Parent.Parent.Controllers.Camera)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)

local PadLabels = {}

local AFFORD = Color3.fromRGB(70, 255, 140)
local LOOK_DELAY = 0.15 -- seconds after a new item appears before the camera looks at it
local TOO_PRICEY = Color3.fromRGB(200, 120, 120)

function PadLabels.start()
	local player = Players.LocalPlayer

	local function cash(): number
		local value = player:GetAttribute("Cash")
		return if typeof(value) == "number" then value else 0
	end

	local function colour(pad: Instance)
		local price = pad:GetAttribute("Price")
		local text = pad:FindFirstChild("Price", true)
		if typeof(price) == "number" and text and text:IsA("TextLabel") then
			text.TextColor3 = if cash() >= price then AFFORD else TOO_PRICEY
		end
	end

	local pads: Instance? = nil
	local function colourAll()
		if pads then
			for _, pad in pads:GetChildren() do
				colour(pad)
			end
		end
	end

	local function watch(plot: Instance)
		-- A pop when something new appears on the plot (not for what was rebuilt on joining), and
		-- a short look at it.
		local joinedAt = os.clock()
		plot:WaitForChild("Items").ChildAdded:Connect(function(item)
			if os.clock() - joinedAt <= 3 then
				return
			end
			Sfx.play("buildPop")
			task.wait(LOOK_DELAY) -- its parts arrive just after it
			local sum, count = Vector3.zero, 0
			for _, part in item:GetDescendants() do
				if part:IsA("BasePart") then
					sum += part.CFrame.Position
					count += 1
				end
			end
			if count > 0 then
				Camera.peek(sum / count)
			end
		end)
		local folder = plot:WaitForChild("Pads")
		pads = folder
		folder.ChildAdded:Connect(function(pad)
			-- The label can replicate a moment after the pad itself.
			pad:WaitForChild("PadGui", 5)
			colour(pad)
		end)
		colourAll()
	end

	player:GetAttributeChangedSignal("Cash"):Connect(colourAll)

	-- The server tells the player which plot is theirs.
	task.spawn(function()
		watch(OwnPlot.wait())
	end)
end

return PadLabels
