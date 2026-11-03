--!strict
-- The set screen: the DJ panel (two decks with overview bars, the crossfader with its blend zone,
-- the main button with its timing ring), track cards, the crowd's wish, energy meter, combo, timer,
-- grade pop-ups and the results card. Holds no game logic: SetDirector tells it what to show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local CrowdView = require(script.Parent.CrowdView)
local Types = require(ReplicatedStorage.Shared.Types)

local SetUI = {}
SetUI.__index = SetUI

local FONT = Enum.Font.BuilderSans
local FONT_BOLD = Enum.Font.BuilderSansBold

local COLORS = {
	background = Color3.fromRGB(10, 10, 16),
	panel = Color3.fromRGB(22, 22, 32),
	inset = Color3.fromRGB(34, 34, 48),
	text = Color3.fromRGB(235, 235, 245),
	dim = Color3.fromRGB(140, 140, 160),
	zone = Color3.fromRGB(70, 230, 120),
	perfect = Color3.fromRGB(255, 215, 90),
	good = Color3.fromRGB(120, 220, 255),
	miss = Color3.fromRGB(255, 100, 110),
}

local SECTION_COLORS: { [Types.SectionKind]: Color3 } = {
	intro = Color3.fromRGB(70, 90, 140),
	build = Color3.fromRGB(205, 150, 40),
	drop = Color3.fromRGB(225, 50, 115),
	breakdown = Color3.fromRGB(50, 125, 205),
	outro = Color3.fromRGB(95, 95, 110),
}

local GRADE_TEXT = { perfect = "PERFECT!", good = "GOOD", miss = "MISS" }

export type Results = {
	grade: string,
	score: number,
	average: number,
	peak: number,
	perfectDrops: number,
	misses: number,
}

export type Card = { title: string, genre: string, energy: number, bpm: number, wished: boolean }

type DeckView = { frame: Frame, title: TextLabel, info: TextLabel, sections: Frame, playhead: Frame, live: TextLabel }

export type SetUI = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		crowd: CrowdView.CrowdView,
		mainButton: TextButton,
		crossfaderTrack: Frame,
		cardButtons: { TextButton },
		_accent: Color3,
		_decks: { DeckView },
		_handle: Frame,
		_zone: Frame,
		_ring: Frame,
		_prompt: TextLabel,
		_countdown: TextLabel,
		_holdFill: Frame,
		_energyFill: Frame,
		_energyLabel: TextLabel,
		_combo: TextLabel,
		_timer: TextLabel,
		_status: TextLabel,
		_grade: TextLabel,
		_cards: Frame,
		_wish: TextLabel,
		_results: Frame,
		_resultGrade: TextLabel,
		_resultText: TextLabel,
	},
	SetUI
))

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function frame(parent: Instance, name: string, colour: Color3?, size: UDim2, position: UDim2): Frame
	local newFrame = Instance.new("Frame")
	newFrame.Name = name
	newFrame.BorderSizePixel = 0
	newFrame.BackgroundColor3 = colour or COLORS.panel
	newFrame.BackgroundTransparency = if colour then 0 else 1
	newFrame.Size = size
	newFrame.Position = position
	newFrame.Parent = parent
	return newFrame
end

local function label(parent: Instance, text: string, size: number, bold: boolean?): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = if bold then FONT_BOLD else FONT
	textLabel.TextSize = size
	textLabel.TextColor3 = COLORS.text
	textLabel.Text = text
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Parent = parent
	return textLabel
end

local function buildDeck(parent: Instance, name: string, position: UDim2): DeckView
	local deck = frame(parent, name, COLORS.inset, UDim2.fromScale(0.29, 0.8), position)
	corner(deck, UDim.new(0, 10))
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	padding.Parent = deck

	local title = label(deck, "-", 20, true)
	title.Size = UDim2.new(1, -60, 0, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local info = label(deck, "", 14)
	info.Size = UDim2.new(1, 0, 0, 18)
	info.Position = UDim2.fromOffset(0, 26)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.TextColor3 = COLORS.dim
	local live = label(deck, "LIVE", 13, true)
	live.Size = UDim2.fromOffset(54, 22)
	live.AnchorPoint = Vector2.new(1, 0)
	live.Position = UDim2.fromScale(1, 0)
	live.BackgroundTransparency = 0
	live.BackgroundColor3 = COLORS.miss
	corner(live, UDim.new(0, 6))
	live.Visible = false

	local bar = frame(deck, "Overview", COLORS.panel, UDim2.new(1, 0, 1, -56), UDim2.fromOffset(0, 54))
	bar.ClipsDescendants = true
	corner(bar, UDim.new(0, 6))
	local sections = frame(bar, "Sections", nil, UDim2.fromScale(1, 1), UDim2.new())
	local playhead = frame(bar, "Playhead", COLORS.text, UDim2.new(0, 2, 1, 0), UDim2.new())
	playhead.ZIndex = 3
	return { frame = deck, title = title, info = info, sections = sections, playhead = playhead, live = live }
end

function SetUI.new(playerGui: Instance, venueName: string, accent: Color3): SetUI
	local gui = Instance.new("ScreenGui")
	gui.Name = "SetScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local background = frame(gui, "Background", COLORS.background, UDim2.fromScale(1, 1), UDim2.new())
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(26, 16, 40), COLORS.background)
	gradient.Parent = background

	local crowd = CrowdView.new(gui, accent)

	-- HUD over the stage
	local venue = label(gui, string.upper(venueName) .. "   ·   PROTOTYPE", 16, true)
	venue.Size = UDim2.fromOffset(420, 24)
	venue.Position = UDim2.fromOffset(20, 64)
	venue.TextXAlignment = Enum.TextXAlignment.Left
	venue.TextColor3 = accent
	local timer = label(gui, "4:00", 30, true)
	timer.Size = UDim2.fromOffset(200, 34)
	timer.Position = UDim2.fromOffset(20, 88)
	timer.TextXAlignment = Enum.TextXAlignment.Left

	local meter = frame(gui, "Energy", COLORS.inset, UDim2.fromOffset(280, 18), UDim2.new(1, -300, 0, 74))
	corner(meter, UDim.new(0, 9))
	local energyFill = frame(meter, "Fill", accent, UDim2.fromScale(0.3, 1), UDim2.new())
	corner(energyFill, UDim.new(0, 9))
	local energyLabel = label(gui, "ENERGY 30", 14, true)
	energyLabel.Size = UDim2.fromOffset(280, 18)
	energyLabel.Position = UDim2.new(1, -300, 0, 96)
	energyLabel.TextXAlignment = Enum.TextXAlignment.Left
	local combo = label(gui, "", 26, true)
	combo.Size = UDim2.fromOffset(120, 30)
	combo.Position = UDim2.new(1, -140, 0, 92)
	combo.TextXAlignment = Enum.TextXAlignment.Right
	combo.TextColor3 = COLORS.perfect

	local status = label(gui, "", 18)
	status.Size = UDim2.new(0.5, 0, 0, 24)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 70)
	status.TextColor3 = COLORS.dim

	local grade = label(gui, "", 64, true)
	grade.Size = UDim2.fromOffset(600, 80)
	grade.AnchorPoint = Vector2.new(0.5, 0.5)
	grade.Position = UDim2.fromScale(0.5, 0.3)
	grade.TextTransparency = 1
	grade.ZIndex = 30

	local wish = label(gui, "", 22, true)
	wish.Size = UDim2.fromOffset(260, 44)
	wish.AnchorPoint = Vector2.new(0.5, 0.5)
	wish.Position = UDim2.fromScale(0.5, 0.42)
	wish.BackgroundTransparency = 0
	wish.BackgroundColor3 = COLORS.text
	wish.TextColor3 = COLORS.background
	wish.Visible = false
	wish.ZIndex = 25
	corner(wish, UDim.new(0, 22))

	-- Track cards, bottom right of the stage
	local cards = frame(gui, "Cards", nil, UDim2.fromScale(0.52, 0.16), UDim2.fromScale(0.985, 0.635))
	cards.AnchorPoint = Vector2.new(1, 1)
	cards.Visible = false
	cards.ZIndex = 24
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.Parent = cards
	local cardButtons = {}
	for i = 1, Balance.Cards.count do
		local card = Instance.new("TextButton")
		card.Name = "Card" .. i
		card.AutoButtonColor = true
		card.BackgroundColor3 = COLORS.inset
		card.BorderSizePixel = 0
		card.Size = UDim2.fromScale(0.32, 1)
		card.LayoutOrder = i
		card.Font = FONT
		card.TextSize = 15
		card.TextColor3 = COLORS.text
		card.TextWrapped = true
		card.Text = ""
		card.ZIndex = 24
		corner(card, UDim.new(0, 10))
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Wished"
		stroke.Thickness = 3
		stroke.Color = COLORS.zone
		stroke.Enabled = false
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = card
		card.Parent = cards
		cardButtons[i] = card
	end

	-- The DJ panel
	local panel = frame(gui, "Panel", COLORS.panel, UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65))
	local deckA = buildDeck(panel, "DeckA", UDim2.fromScale(0.015, 0.1))
	local deckB = buildDeck(panel, "DeckB", UDim2.fromScale(0.695, 0.1))
	local centre = frame(panel, "Centre", nil, UDim2.fromScale(0.36, 1), UDim2.fromScale(0.32, 0))

	local prompt = label(centre, "", 20, true)
	prompt.Size = UDim2.new(1, 0, 0, 24)
	prompt.Position = UDim2.fromScale(0, 0.03)
	prompt.TextColor3 = accent

	local mainButton = Instance.new("TextButton")
	mainButton.Name = "MainButton"
	mainButton.AutoButtonColor = false
	mainButton.BackgroundColor3 = COLORS.inset
	mainButton.BorderSizePixel = 0
	mainButton.AnchorPoint = Vector2.new(0.5, 0.5)
	mainButton.Position = UDim2.fromScale(0.5, 0.42)
	mainButton.Size = UDim2.fromOffset(104, 104)
	mainButton.Font = FONT_BOLD
	mainButton.TextSize = 14
	mainButton.TextColor3 = COLORS.dim
	mainButton.Text = "SPACE"
	mainButton.ZIndex = 5
	corner(mainButton, UDim.new(0.5, 0))
	mainButton.Parent = centre
	local holdFill = frame(mainButton, "Hold", accent, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1))
	holdFill.AnchorPoint = Vector2.new(0, 1)
	holdFill.BackgroundTransparency = 0.4
	holdFill.ZIndex = 5
	corner(holdFill, UDim.new(0.5, 0))
	local countdown = label(mainButton, "", 44, true)
	countdown.ZIndex = 6

	local ring = frame(centre, "Ring", nil, UDim2.fromOffset(104, 104), UDim2.fromScale(0.5, 0.42))
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Visible = false
	ring.ZIndex = 6
	corner(ring, UDim.new(0.5, 0))
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Thickness = 5
	ringStroke.Color = accent
	ringStroke.Parent = ring

	local track = frame(centre, "Crossfader", COLORS.inset, UDim2.new(0.86, 0, 0, 16), UDim2.fromScale(0.5, 0.84))
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(track, UDim.new(0, 8))
	local zone =
		frame(track, "Zone", COLORS.zone, UDim2.fromScale(Balance.Blend.zoneWidth, 1.8), UDim2.fromScale(0, 0.5))
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.BackgroundTransparency = 0.45
	zone.Visible = false
	corner(zone, UDim.new(0, 8))
	local handle = frame(track, "Handle", COLORS.text, UDim2.fromOffset(26, 46), UDim2.fromScale(0, 0.5))
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.ZIndex = 3
	corner(handle, UDim.new(0, 6))
	for i, letter in { "A", "B" } do
		local side = label(centre, letter, 16, true)
		side.Size = UDim2.fromOffset(20, 20)
		side.AnchorPoint = Vector2.new(0.5, 0.5)
		side.Position = UDim2.fromScale(if i == 1 then 0.03 else 0.97, 0.84)
		side.TextColor3 = COLORS.dim
	end

	-- Results card
	local results = frame(gui, "Results", COLORS.panel, UDim2.fromOffset(420, 330), UDim2.fromScale(0.5, 0.45))
	results.AnchorPoint = Vector2.new(0.5, 0.5)
	results.Visible = false
	results.ZIndex = 40
	corner(results, UDim.new(0, 16))
	local resultGrade = label(results, "", 110, true)
	resultGrade.Size = UDim2.new(1, 0, 0, 130)
	resultGrade.TextColor3 = accent
	resultGrade.ZIndex = 41
	local resultText = label(results, "", 18)
	resultText.Size = UDim2.new(1, -40, 0, 170)
	resultText.Position = UDim2.fromOffset(20, 130)
	resultText.TextYAlignment = Enum.TextYAlignment.Top
	resultText.ZIndex = 41

	gui.Parent = playerGui
	return setmetatable({
		gui = gui,
		crowd = crowd,
		mainButton = mainButton,
		crossfaderTrack = track,
		cardButtons = cardButtons,
		_accent = accent,
		_decks = { deckA, deckB },
		_handle = handle,
		_zone = zone,
		_ring = ring,
		_prompt = prompt,
		_countdown = countdown,
		_holdFill = holdFill,
		_energyFill = energyFill,
		_energyLabel = energyLabel,
		_combo = combo,
		_timer = timer,
		_status = status,
		_grade = grade,
		_cards = cards,
		_wish = wish,
		_results = results,
		_resultGrade = resultGrade,
		_resultText = resultText,
	}, SetUI)
end

-- Shows a track on a deck, with its sections drawn across the overview bar.
function SetUI.setDeck(self: SetUI, deck: number, track: Types.Track?, lengthSeconds: number)
	local view = self._decks[deck]
	for _, child in view.sections:GetChildren() do
		child:Destroy()
	end
	if not track then
		view.title.Text, view.info.Text = "-", ""
		return
	end
	view.title.Text = track.title
	view.info.Text = string.format("%s   ·   %s BPM   ·   %s", track.artist, track.bpm, track.genre)
	for i, section in track.sections do
		local startTime = BeatMath.beatToTime(section.startBeat, track.bpm, track.firstBeat)
		local nextSection = track.sections[i + 1]
		local endTime = if nextSection
			then BeatMath.beatToTime(nextSection.startBeat, track.bpm, track.firstBeat)
			else lengthSeconds
		local block = frame(
			view.sections,
			section.kind,
			SECTION_COLORS[section.kind],
			UDim2.fromScale((endTime - startTime) / lengthSeconds, 1),
			UDim2.fromScale(startTime / lengthSeconds, 0)
		)
		block.BackgroundTransparency = 0.3
	end
end

function SetUI.setPlayhead(self: SetUI, deck: number, fraction: number)
	self._decks[deck].playhead.Position = UDim2.fromScale(math.clamp(fraction, 0, 1), 0)
end

function SetUI.setLive(self: SetUI, master: number)
	for i, view in self._decks do
		view.live.Visible = i == master
	end
end

function SetUI.setEnergy(self: SetUI, energy: number, combo: number)
	self._energyFill.Size = UDim2.fromScale(math.clamp(energy / 100, 0.02, 1), 1)
	self._energyLabel.Text = string.format("ENERGY %d", math.round(energy))
	self._combo.Text = if combo > 1 then string.format("x%s", combo) else ""
end

function SetUI.setTimer(self: SetUI, secondsLeft: number)
	local s = math.max(0, math.ceil(secondsLeft))
	self._timer.Text = string.format("%d:%02d", s // 60, s % 60)
end

function SetUI.setStatus(self: SetUI, text: string)
	self._status.Text = text
end

function SetUI.setCrossfader(self: SetUI, position: number)
	self._handle.Position = UDim2.fromScale(math.clamp(position, 0, 1), 0.5)
end

-- The green blend zone around `centre` (0..1), or hidden when nil. `inside` brightens it.
function SetUI.setZone(self: SetUI, centre: number?, inside: boolean?)
	self._zone.Visible = centre ~= nil
	if centre then
		self._zone.Position = UDim2.fromScale(centre, 0.5)
		self._zone.BackgroundTransparency = if inside then 0.15 else 0.55
	end
end

-- The timing prompt over the main button. `ring` runs 1 -> 0 as the target nears; `hold` (0..1)
-- fills the button for a Release. Call with nil to hide it.
function SetUI.setPrompt(self: SetUI, text: string?, countdown: string?, ring: number?, hold: number?)
	self._prompt.Text = text or ""
	self._countdown.Text = countdown or ""
	self.mainButton.Text = if text then "" else "SPACE"
	self._ring.Visible = ring ~= nil
	if ring then
		local size = 104 * (1 + 1.4 * math.clamp(ring, 0, 1))
		self._ring.Size = UDim2.fromOffset(size, size)
	end
	self._holdFill.Size = UDim2.fromScale(1, math.clamp(hold or 0, 0, 1))
end

function SetUI.setButtonPressed(self: SetUI, pressed: boolean)
	self.mainButton.BackgroundColor3 = if pressed then self._accent else COLORS.inset
end

-- A grade word popping up over the stage.
function SetUI.popGrade(self: SetUI, grade: string, extra: string?)
	local text = (GRADE_TEXT :: any)[grade] or grade
	self._grade.Text = if extra then text .. "  " .. extra else text
	self._grade.TextColor3 = (COLORS :: any)[grade] or COLORS.text
	self._grade.TextTransparency = 0
	self._grade.Position = UDim2.fromScale(0.5, 0.32)
	TweenService:Create(self._grade, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.26),
	}):Play()
end

-- The track cards (nil hides them). Wished cards get a green outline.
function SetUI.setCards(self: SetUI, cards: { Card }?, picked: number?)
	self._cards.Visible = cards ~= nil
	if not cards then
		return
	end
	for i, button in self.cardButtons do
		local card = cards[i]
		button.Visible = card ~= nil
		if card then
			button.Text = string.format(
				"[%d]\n%s\n%s · %s BPM\nenergy %s",
				i,
				card.title,
				card.genre,
				card.bpm,
				string.rep("●", card.energy) .. string.rep("○", 5 - card.energy)
			)
			button.BackgroundColor3 = if picked == i then self._accent else COLORS.inset
			button.TextColor3 = if picked == i then COLORS.background else COLORS.text
			local stroke = button:FindFirstChild("Wished") :: UIStroke
			stroke.Enabled = card.wished
		end
	end
end

function SetUI.setWish(self: SetUI, text: string?)
	self._wish.Visible = text ~= nil
	self._wish.Text = text or ""
end

function SetUI.showResults(self: SetUI, results: Results?)
	self._results.Visible = results ~= nil
	if results then
		self._resultGrade.Text = results.grade
		self._resultText.Text = string.format(
			"Score %d\nAverage energy %d   ·   Peak %d\nPerfect drops %d   ·   Misses %d\n\nPress R or tap here to play again",
			math.round(results.score),
			math.round(results.average),
			math.round(results.peak),
			results.perfectDrops,
			results.misses
		)
	end
end

function SetUI.resultsFrame(self: SetUI): Frame
	return self._results
end

return SetUI
