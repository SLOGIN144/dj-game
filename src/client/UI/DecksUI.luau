--!strict
-- The decks screen (GDD: at the decks): a big round main button bottom centre (about 96 px), a
-- ring that closes in on it in time with the beat before each drop with a 4-3-2-1 count, the
-- playing track's title and a small bar with its drops marked, "Perfect" / "Good" on a press, and
-- buttons for the track shop and leaving. Controllers/Decks feeds it every frame.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Style = require(script.Parent.Style)

local DecksUI = {}

local BUTTON = 96
local RING_GROWTH = 0.5 -- the ring is this many button sizes bigger per beat before the drop
local BAR_WIDTH = 320
local POP = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type View = {
	title: string, -- "Title - Artist"
	progress: number, -- 0..1 through the track's tagged sections
	drops: { number }, -- 0..1 positions of the track's drops on the bar
	beatsToDrop: number?, -- beats until the next drop, while it's close
	secondsToDrop: number?, -- seconds until the next drop
	kick: number, -- 1 on the beat, falling to 0 before the next
}

export type Handlers = { press: () -> (), leave: () -> (), tracks: () -> () }

local gui: ScreenGui
local ring: Frame
local ringStroke: UIStroke
local mainButton: TextButton
local buttonScale: UIScale
local count: TextLabel
local gradeLabel: TextLabel
local title: TextLabel
local fill: Frame
local marks: Frame
local nextDrop: TextLabel
local shownDrops = ""

local GRADE_TEXT = { perfect = "PERFECT!", good = "GOOD", miss = "MISS" }
local GRADE_COLOUR = { perfect = Style.GOLD, good = Style.GOOD, miss = Style.MUTED }

function DecksUI.build(handlers: Handlers)
	local accent = Style.accent()
	gui = Instance.new("ScreenGui")
	gui.Name = "Decks"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -28)
	bottom.Size = UDim2.fromOffset(BAR_WIDTH + 40, BUTTON + 120)
	bottom.BackgroundTransparency = 1
	bottom.Parent = gui

	-- The track: title, bar and drop marks
	nextDrop =
		Style.label(bottom, "NextDrop", "", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 0), Style.MUTED, Style.BODY)
	title = Style.label(bottom, "Title", "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 20))
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 48)
	bar.Size = UDim2.fromOffset(BAR_WIDTH, 6)
	bar.BackgroundColor3 = Style.PANEL
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Parent = bottom
	Style.corner(bar, UDim.new(1, 0))
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	Style.follow(fill, "BackgroundColor3")
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Style.corner(fill, UDim.new(1, 0))
	marks = Instance.new("Frame")
	marks.Name = "Drops"
	marks.Size = UDim2.fromScale(1, 1)
	marks.BackgroundTransparency = 1
	marks.Parent = bar

	-- The main button with its ring and count
	mainButton = Instance.new("TextButton")
	mainButton.Name = "Main"
	mainButton.AnchorPoint = Vector2.new(0.5, 1)
	mainButton.Position = UDim2.fromScale(0.5, 1)
	mainButton.Size = UDim2.fromOffset(BUTTON, BUTTON)
	mainButton.BackgroundColor3 = Style.PANEL
	mainButton.BackgroundTransparency = 0.05
	mainButton.Text = ""
	mainButton.AutoButtonColor = true
	mainButton.Parent = bottom
	Style.corner(mainButton, UDim.new(0.5, 0))
	Style.follow(Style.stroke(mainButton, accent, 3), "Color")
	buttonScale = Instance.new("UIScale")
	buttonScale.Parent = mainButton
	count = Style.label(mainButton, "Count", "DROP", UDim2.fromScale(0.7, 0.4), UDim2.fromScale(0.15, 0.3))
	mainButton.Activated:Connect(handlers.press)

	ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 1, -BUTTON / 2)
	ring.Size = UDim2.fromOffset(BUTTON, BUTTON)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	ring.Parent = bottom
	Style.corner(ring, UDim.new(0.5, 0))
	ringStroke = Style.follow(Style.stroke(ring, accent, 4), "Color")

	gradeLabel = Style.label(bottom, "Grade", "", UDim2.fromOffset(240, 40), UDim2.new(0.5, -120, 0, 64), Style.GOLD)
	gradeLabel.TextTransparency = 1
	gradeLabel.TextStrokeTransparency = 1

	-- Side buttons
	local tracks = Style.button(bottom, "Tracks", "Tracks", UDim2.fromOffset(96, 40), UDim2.new(0, 0, 1, -68))
	tracks.Activated:Connect(handlers.tracks)
	local leave = Style.button(bottom, "Leave", "Leave", UDim2.fromOffset(96, 40), UDim2.new(1, -96, 1, -68))
	leave.Activated:Connect(handlers.leave)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function DecksUI.show(visible: boolean)
	gui.Enabled = visible
end

local function placeDrops(drops: { number })
	local key = table.concat(drops, ",")
	if key == shownDrops then
		return
	end
	shownDrops = key
	marks:ClearAllChildren()
	for _, position in drops do
		local mark = Instance.new("Frame")
		mark.Name = "Drop"
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(math.clamp(position, 0, 1), 0.5)
		mark.Size = UDim2.fromOffset(3, 14)
		mark.BackgroundColor3 = Style.GOLD
		mark.BorderSizePixel = 0
		mark.Parent = marks
	end
end

function DecksUI.update(view: View)
	title.Text = view.title
	fill.Size = UDim2.fromScale(math.clamp(view.progress, 0, 1), 1)
	placeDrops(view.drops)
	buttonScale.Scale = 1 + 0.05 * view.kick

	local beats = view.beatsToDrop
	if beats and beats > 0 then
		ring.Visible = true
		local size = BUTTON * (1 + beats * RING_GROWTH)
		ring.Size = UDim2.fromOffset(size, size)
		ringStroke.Transparency = math.clamp(beats / 6, 0, 0.6)
		count.Text = tostring(math.ceil(beats))
	elseif beats then
		ring.Visible = false
		count.Text = "NOW!"
	else
		ring.Visible = false
		count.Text = "DROP"
	end

	local seconds = view.secondsToDrop
	nextDrop.Text = if seconds and seconds > 3 then string.format("Next drop in %d s", math.floor(seconds)) else ""
end

-- "PERFECT!", "GOOD" or "MISS" rising above the button.
function DecksUI.grade(grade: string)
	local text = GRADE_TEXT[grade]
	if not text then
		return
	end
	gradeLabel.Text = text
	gradeLabel.TextColor3 = GRADE_COLOUR[grade]
	gradeLabel.Position = UDim2.new(0.5, -120, 0, 64)
	gradeLabel.TextTransparency = 0
	gradeLabel.TextStrokeTransparency = 0.4
	TweenService:Create(gradeLabel, POP, {
		Position = UDim2.new(0.5, -120, 0, 24),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

return DecksUI
