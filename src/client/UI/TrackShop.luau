--!strict
-- The track shop panel, opened from the decks: every track with its price and a Buy button, and
-- which ones the player owns or is playing. Tracks cost cash only and can't be played from here
-- (no music library); the server checks each purchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hud = require(script.Parent.Hud)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local PlotMixes = require(script.Parent.Parent.Controllers.PlotMixes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Style = require(script.Parent.Style)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Types = require(ReplicatedStorage.Shared.Types)

local TrackShop = {}

local ROW_HEIGHT = 54
local REFRESH = 0.5

type Row = { button: TextButton, status: TextLabel }

local player = Players.LocalPlayer
local gui: ScreenGui
local rows: { [string]: Row } = {}

local function owned(): { [string]: boolean }
	local set = {}
	local text = player:GetAttribute("OwnedTracks")
	if typeof(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

local function playingId(): string?
	local plot = OwnPlot.get()
	if not plot then
		return nil
	end
	local _, main = PlotMixes.at(plot, PlotMixes.now())
	return if main then main.track.id else nil
end

local function refresh()
	if not gui or not gui.Enabled then
		return
	end
	local mine = owned()
	local playing = playingId()
	local cash = player:GetAttribute("Cash")
	local money = if typeof(cash) == "number" then cash else 0
	for _, track in Tracks do
		local row = rows[track.id]
		if not row then
			continue
		end
		if mine[track.id] then
			row.button.Visible = false
			row.status.Visible = true
			row.status.Text = if track.id == playing then "Playing" else "Owned"
			row.status.TextColor3 = if track.id == playing then Style.GOLD else Style.MUTED
		else
			row.button.Visible = true
			row.status.Visible = false
			row.button.Text = "Buy " .. Format.money(track.price)
			row.button.TextColor3 = if money >= track.price then Style.GOOD else Style.MUTED
		end
	end
end

local function buildRow(list: ScrollingFrame, order: number, track: Types.Track)
	local row = Instance.new("Frame")
	row.Name = track.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = list
	Style.corner(row, UDim.new(0, 10))
	Style.label(row, "Title", track.title, UDim2.new(0.62, -12, 0, 24), UDim2.fromOffset(12, 6)).TextXAlignment =
		Enum.TextXAlignment.Left
	local details = Style.label(
		row,
		"Details",
		string.format("%s  ·  %s  ·  %d BPM", track.artist, track.genre, track.bpm),
		UDim2.new(0.62, -12, 0, 16),
		UDim2.fromOffset(12, 31),
		Style.MUTED,
		Style.BODY
	)
	details.TextXAlignment = Enum.TextXAlignment.Left

	local button = Style.button(row, "Buy", "Buy", UDim2.new(0.34, 0, 0, 36), UDim2.new(0.64, -8, 0, 9))
	button.Activated:Connect(function()
		Remotes.event("BuyTrack"):FireServer(track.id)
	end)
	local status =
		Style.label(row, "Status", "Owned", UDim2.new(0.34, 0, 0, 26), UDim2.new(0.64, -8, 0, 14), Style.MUTED)
	status.Visible = false
	rows[track.id] = { button = button, status = status }
end

function TrackShop.open()
	gui.Enabled = true
	refresh()
end

function TrackShop.close()
	gui.Enabled = false
end

function TrackShop.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "TrackShop"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10

	local panel = Style.panel(gui, "Panel", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Style.follow(Style.stroke(panel, Style.accent()), "Color")
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 420)
	limit.Parent = panel

	Style.label(panel, "Title", "Track Shop", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(16, 10)).TextXAlignment =
		Enum.TextXAlignment.Left
	local subtitle = Style.label(
		panel,
		"Subtitle",
		string.format(
			"Each track you buy joins your mix and adds +%d%% income for good.",
			math.round(Balance.Tracks.bonusPerTrack * 100)
		),
		UDim2.new(1, -32, 0, 16),
		UDim2.fromOffset(16, 42),
		Style.MUTED,
		Style.BODY
	)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Style.button(panel, "Close", "X", UDim2.fromOffset(40, 40), UDim2.new(1, -52, 0, 8))
	close.Activated:Connect(TrackShop.close)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 68)
	list.Size = UDim2.new(1, -24, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for order, track in Tracks do
		buildRow(list, order, track)
	end

	Remotes.event("TrackResult").OnClientEvent:Connect(function(_: unknown, ok: unknown, reason: unknown)
		if ok == true then
			Sfx.play("buy")
			Hud.float("New track in your mix!", Style.GOLD)
		elseif reason == "cash" then
			Hud.float("Not enough cash yet", Style.BAD)
		end
		refresh()
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	player:GetAttributeChangedSignal("OwnedTracks"):Connect(refresh)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= REFRESH then
			since = 0
			refresh()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return TrackShop
