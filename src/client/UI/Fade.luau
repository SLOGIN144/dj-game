--!strict
-- The screen fade while the server moves the player's character (Services/Travel): to dark with
-- a line of text ("Flying to Ibiza Beach Club..."), then back once they've arrived. If the fade
-- back never comes, it lifts by itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Style = require(script.Parent.Style)

local Fade = {}

local OUT = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BACK = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOLD = 0.25 -- seconds it stays dark after arriving, while the new place streams in
local FAILSAFE = 10 -- seconds after which it lifts anyway

function Fade.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Fade"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Active = false
	cover.Parent = gui
	local line = Style.label(cover, "Line", "", UDim2.new(0.6, 0, 0, 40), UDim2.fromScale(0.2, 0.46))
	line.TextTransparency = 1
	Style.follow(line, "TextColor3")

	local token = 0
	local function back()
		TweenService:Create(cover, BACK, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, BACK, { TextTransparency = 1 }):Play()
	end

	Remotes.event("Travel").OnClientEvent:Connect(function(phase: unknown, text: unknown)
		token += 1
		local mine = token
		if phase == "out" then
			line.Text = if typeof(text) == "string" then text else ""
			TweenService:Create(cover, OUT, { BackgroundTransparency = 0 }):Play()
			TweenService:Create(line, OUT, { TextTransparency = 0 }):Play()
			task.delay(FAILSAFE, function()
				if token == mine then
					back()
				end
			end)
		elseif phase == "in" then
			task.delay(HOLD, function()
				if token == mine then
					back()
				end
			end)
		end
	end)
end

return Fade
