--!strict
-- The board on the street (GDD: multiplayer and social): it ranks the players in this server by
-- total cash earned, with the location each one has reached. It draws on the billboard's screen
-- at the near end of the street (World/StreetProps). The same number shows in Roblox's player list
-- ("leaderstats"). A global leaderboard comes later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)

local Leaderboard = {}

local REFRESH = 5 -- seconds between updates
local ROWS = 6
local TITLE = Color3.fromRGB(60, 160, 255)
local GOLD = Color3.fromRGB(255, 214, 90)
local TEXT = Color3.fromRGB(240, 240, 250)
local MUTED = Color3.fromRGB(170, 170, 190)

-- The player's "Earned" value in Roblox's player list.
local function earnedStat(player: Player): IntValue
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats" -- the name Roblox's player list looks for
		created.Parent = player
		folder = created
	end
	local existing = (folder :: Instance):FindFirstChild("Earned")
	if existing and existing:IsA("IntValue") then
		return existing
	end
	local value = Instance.new("IntValue")
	value.Name = "Earned"
	value.Parent = folder
	return value
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, colour: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position
	item.Text = text
	item.TextColor3 = colour
	item.TextScaled = true
	item.Font = Enum.Font.BuilderSansExtraBold
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

-- Draws the board on `screen` and keeps it up to date.
function Leaderboard.start(screen: BasePart?)
	if not screen then
		warn("[Leaderboard] no billboard screen on the street")
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = screen
	label(gui, "TOP CLUBS TONIGHT", UDim2.fromScale(0.9, 0.16), UDim2.fromScale(0.05, 0.04), TITLE).TextXAlignment =
		Enum.TextXAlignment.Center

	local rows: { { rank: TextLabel, name: TextLabel, place: TextLabel, cash: TextLabel } } = {}
	for index = 1, ROWS do
		local y = 0.22 + (index - 1) * 0.125
		local height = UDim2.fromScale(0, 0.1)
		rows[index] = {
			rank = label(gui, "", height + UDim2.fromScale(0.07, 0), UDim2.fromScale(0.05, y), GOLD),
			name = label(gui, "", height + UDim2.fromScale(0.4, 0), UDim2.fromScale(0.13, y), TEXT),
			place = label(gui, "", height + UDim2.fromScale(0.25, 0), UDim2.fromScale(0.54, y), MUTED),
			cash = label(gui, "", height + UDim2.fromScale(0.16, 0), UDim2.fromScale(0.8, y), GOLD),
		}
	end

	task.spawn(function()
		while true do
			local ranked = {}
			for _, state in PlayerState.all() do
				table.insert(ranked, state)
				earnedStat(state.player).Value = math.floor(state.totalEarned)
			end
			table.sort(ranked, function(a, b)
				return a.totalEarned > b.totalEarned
			end)
			for index, row in rows do
				local state = ranked[index]
				local location = if state then PlotSpace.location(state.locationId) else nil
				row.rank.Text = if state then "#" .. index else ""
				row.name.Text = if state then state.player.DisplayName else ""
				row.place.Text = if location then location.name else ""
				row.cash.Text = if state then Format.money(state.totalEarned) else ""
			end
			task.wait(REFRESH)
		end
	end)
end

return Leaderboard
