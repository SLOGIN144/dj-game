--!strict
-- Builds the Track Tagger screen and offers small functions to redraw parts of it.
-- Holds no tagging logic: the entry script reads input and state, then calls these.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local Types = require(ReplicatedStorage.Shared.Types)

local TaggerUI = {}

local FONT = Enum.Font.BuilderSans
local FONT_BOLD = Enum.Font.BuilderSansBold
local MONO = Enum.Font.RobotoMono

local COLORS = {
	background = Color3.fromRGB(16, 16, 22),
	panel = Color3.fromRGB(32, 32, 44),
	text = Color3.fromRGB(232, 232, 240),
	dim = Color3.fromRGB(140, 140, 160),
	accent = Color3.fromRGB(170, 90, 255),
	error = Color3.fromRGB(255, 110, 110),
	downbeat = Color3.fromRGB(255, 255, 255),
	firstBeat = Color3.fromRGB(80, 220, 120),
	cue = Color3.fromRGB(255, 200, 60),
}

local SECTION_COLORS: { [Types.SectionKind]: Color3 } = {
	intro = Color3.fromRGB(70, 90, 140),
	build = Color3.fromRGB(205, 150, 40),
	drop = Color3.fromRGB(225, 50, 115),
	breakdown = Color3.fromRGB(50, 125, 205),
	outro = Color3.fromRGB(95, 95, 110),
}

-- Text boxes for the parts of the entry the tagger can't measure, with their default text.
local FIELDS: { { name: string, width: number, default: string } } = {
	{ name = "id", width = 0.2, default = "" },
	{ name = "title", width = 0.24, default = "" },
	{ name = "artist", width = 0.2, default = "" },
	{ name = "genre", width = 0.12, default = "house" },
	{ name = "energy", width = 0.07, default = "3" },
	{ name = "tier", width = 0.07, default = "1" },
	{ name = "price", width = 0.1, default = "250" },
}

local HELP = table.concat({
	"Load finds the tempo, first beat, sections and cue by itself. The keys below are only for fixing things.",
	"Space play/pause   ← → jump 1 bar (Shift: 1 beat)   Home back to bar 1   click the bar above to jump there",
	"T tap on every beat (32 taps is best)   R reset taps   B whole-BPM rounding on/off",
	"D mark the first downbeat (press on a 1)   , and . nudge it 5 ms earlier/later (Shift: 1 ms)",
	"1 intro   2 build   3 drop   4 breakdown   5 outro   Backspace remove section   C cue point   E export",
	"Keys don't work while a text box is selected: click on the dark background first.",
}, "\n")

export type UI = {
	gui: ScreenGui,
	assetBox: TextBox,
	loadButton: TextButton,
	autoButton: TextButton,
	status: TextLabel,
	fields: { [string]: TextBox },
	overview: TextButton,
	overviewHint: TextLabel,
	sectionLayer: Frame,
	waveformLayer: Frame,
	tickLayer: Frame,
	markerLayer: Frame,
	playhead: Frame,
	beatLight: Frame,
	beatLabel: TextLabel,
	readout: TextLabel,
	exportBox: TextBox,
}

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function padding(parent: Instance, left: number, top: number): UIPadding
	local uiPadding = Instance.new("UIPadding")
	uiPadding.PaddingLeft = UDim.new(0, left)
	uiPadding.PaddingRight = UDim.new(0, left)
	uiPadding.PaddingTop = UDim.new(0, top)
	uiPadding.PaddingBottom = UDim.new(0, top)
	uiPadding.Parent = parent
	return uiPadding
end

local function listLayout(parent: Instance, direction: Enum.FillDirection, gap: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = parent
end

local function frame(parent: Instance, size: UDim2, order: number): Frame
	local newFrame = Instance.new("Frame")
	newFrame.BackgroundTransparency = 1
	newFrame.BorderSizePixel = 0
	newFrame.Size = size
	newFrame.LayoutOrder = order
	newFrame.Parent = parent
	return newFrame
end

local function textLabel(parent: Instance, text: string, size: UDim2, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.LayoutOrder = order
	label.Font = FONT
	label.TextSize = 16
	label.TextColor3 = COLORS.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text
	label.Parent = parent
	return label
end

local function textBox(parent: Instance, placeholder: string, size: UDim2, order: number): TextBox
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = COLORS.panel
	box.BorderSizePixel = 0
	box.Size = size
	box.LayoutOrder = order
	box.Font = FONT
	box.TextSize = 16
	box.TextColor3 = COLORS.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = COLORS.dim
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	padding(box, 8, 0)
	corner(box, 6)
	box.Parent = parent
	return box
end

-- A thin vertical line on the overview bar at `fraction` of the track.
local function marker(parent: Instance, fraction: number, color: Color3, heightScale: number, transparency: number)
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = color
	line.BackgroundTransparency = transparency
	line.AnchorPoint = Vector2.new(0.5, 1)
	line.Position = UDim2.fromScale(fraction, 1)
	line.Size = UDim2.new(0, if transparency < 0.5 then 2 else 1, heightScale, 0)
	line.Parent = parent
end

local function overviewLayer(parent: Instance, name: string, zIndex: number): Frame
	local layer = Instance.new("Frame")
	layer.Name = name
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = zIndex
	layer.Parent = parent
	return layer
end

function TaggerUI.new(playerGui: Instance): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "TrackTagger"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true -- cover the strip under Roblox's top bar too

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = COLORS.background
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local rootPadding = padding(root, 16, 12)
	rootPadding.PaddingTop = UDim.new(0, GuiService:GetGuiInset().Y + 12) -- keep clear of the top bar buttons
	listLayout(root, Enum.FillDirection.Vertical, 8)

	local header = textLabel(root, "TRACK TAGGER   dev tool, never shipped", UDim2.new(1, 0, 0, 24), 1)
	header.Font = FONT_BOLD
	header.TextSize = 20

	local loadRow = frame(root, UDim2.new(1, 0, 0, 34), 2)
	loadRow.Name = "LoadRow"
	listLayout(loadRow, Enum.FillDirection.Horizontal, 8)
	local assetBox = textBox(loadRow, "Asset ID of the track", UDim2.fromScale(0.25, 1), 1)
	assetBox.Name = "AssetBox"
	local loadButton = Instance.new("TextButton")
	loadButton.Name = "LoadButton"
	loadButton.BackgroundColor3 = COLORS.accent
	loadButton.BorderSizePixel = 0
	loadButton.Size = UDim2.new(0, 90, 1, 0)
	loadButton.LayoutOrder = 2
	loadButton.Font = FONT_BOLD
	loadButton.TextSize = 16
	loadButton.TextColor3 = COLORS.text
	loadButton.Text = "Load"
	corner(loadButton, 6)
	loadButton.Parent = loadRow
	local autoButton = loadButton:Clone()
	autoButton.Name = "AutoButton"
	autoButton.Size = UDim2.new(0, 150, 1, 0)
	autoButton.LayoutOrder = 3
	autoButton.BackgroundColor3 = COLORS.panel
	autoButton.Text = "Auto-tag picks"
	autoButton.Parent = loadRow
	local status = textLabel(loadRow, "Paste a track's asset ID and press Load.", UDim2.new(0.75, -264, 1, 0), 4)
	status.Name = "Status"
	status.TextColor3 = COLORS.dim
	status.TextTruncate = Enum.TextTruncate.AtEnd

	local metaRow = frame(root, UDim2.new(1, 0, 0, 50), 3)
	metaRow.Name = "MetaRow"
	listLayout(metaRow, Enum.FillDirection.Horizontal, 8)
	local fields: { [string]: TextBox } = {}
	for i, field in FIELDS do
		local cell = frame(metaRow, UDim2.new(field.width, -8, 1, 0), i)
		local caption = textLabel(cell, field.name, UDim2.new(1, 0, 0, 16), 0)
		caption.TextSize = 13
		caption.TextColor3 = COLORS.dim
		local box = textBox(cell, field.name, UDim2.new(1, 0, 0, 32), 0)
		box.Name = field.name
		box.Position = UDim2.fromOffset(0, 18)
		box.Text = field.default
		fields[field.name] = box
	end

	local overview = Instance.new("TextButton")
	overview.Name = "Overview"
	overview.AutoButtonColor = false
	overview.BackgroundColor3 = COLORS.panel
	overview.BorderSizePixel = 0
	overview.ClipsDescendants = true
	overview.Size = UDim2.new(1, 0, 0, 110)
	overview.LayoutOrder = 4
	overview.Text = ""
	corner(overview, 6)
	overview.Parent = root
	local overviewHint = textLabel(overview, "Load a track to see it here.", UDim2.fromScale(1, 1), 0)
	overviewHint.TextXAlignment = Enum.TextXAlignment.Center
	overviewHint.TextColor3 = COLORS.dim
	local sectionLayer = overviewLayer(overview, "Sections", 1)
	local waveformLayer = overviewLayer(overview, "Waveform", 2)
	local tickLayer = overviewLayer(overview, "Ticks", 3)
	local markerLayer = overviewLayer(overview, "Markers", 4)
	local playhead = Instance.new("Frame")
	playhead.Name = "Playhead"
	playhead.BorderSizePixel = 0
	playhead.BackgroundColor3 = COLORS.text
	playhead.AnchorPoint = Vector2.new(0.5, 0)
	playhead.Size = UDim2.new(0, 2, 1, 0)
	playhead.ZIndex = 5
	playhead.Visible = false
	playhead.Parent = overview

	local infoRow = frame(root, UDim2.new(1, 0, 0, 120), 5)
	infoRow.Name = "InfoRow"
	listLayout(infoRow, Enum.FillDirection.Horizontal, 16)
	local beatLight = Instance.new("Frame")
	beatLight.Name = "BeatLight"
	beatLight.BackgroundColor3 = COLORS.panel
	beatLight.BorderSizePixel = 0
	beatLight.Size = UDim2.fromOffset(120, 120)
	beatLight.LayoutOrder = 1
	corner(beatLight, 12)
	beatLight.Parent = infoRow
	local beatLabel = textLabel(beatLight, "", UDim2.fromScale(1, 1), 0)
	beatLabel.TextXAlignment = Enum.TextXAlignment.Center
	beatLabel.Font = FONT_BOLD
	beatLabel.TextSize = 26
	local readout = textLabel(infoRow, "", UDim2.new(1, -136, 1, 0), 2)
	readout.Name = "Readout"
	readout.Font = MONO
	readout.TextSize = 15
	readout.TextYAlignment = Enum.TextYAlignment.Top

	local help = textLabel(root, HELP, UDim2.new(1, 0, 0, 104), 6)
	help.TextSize = 14
	help.TextColor3 = COLORS.dim
	help.TextYAlignment = Enum.TextYAlignment.Top

	local exportFrame = Instance.new("ScrollingFrame")
	exportFrame.BackgroundColor3 = COLORS.panel
	exportFrame.BorderSizePixel = 0
	exportFrame.Size = UDim2.new(1, 0, 1, -490)
	exportFrame.LayoutOrder = 7
	exportFrame.CanvasSize = UDim2.new()
	exportFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	exportFrame.ScrollBarThickness = 6
	corner(exportFrame, 6)
	exportFrame.Parent = root
	local exportBox = Instance.new("TextBox")
	exportBox.Name = "Export"
	exportBox.BackgroundTransparency = 1
	exportBox.Size = UDim2.new(1, -12, 0, 0)
	exportBox.AutomaticSize = Enum.AutomaticSize.Y
	exportBox.Font = MONO
	exportBox.TextSize = 14
	exportBox.TextColor3 = COLORS.text
	exportBox.PlaceholderText = "Press E to export. The entry shows up here and in the Output window."
	exportBox.PlaceholderColor3 = COLORS.dim
	exportBox.Text = ""
	exportBox.MultiLine = true
	exportBox.TextEditable = false
	exportBox.ClearTextOnFocus = false
	exportBox.TextXAlignment = Enum.TextXAlignment.Left
	exportBox.TextYAlignment = Enum.TextYAlignment.Top
	padding(exportBox, 10, 8)
	exportBox.Parent = exportFrame

	gui.Parent = playerGui

	return {
		gui = gui,
		assetBox = assetBox,
		loadButton = loadButton,
		autoButton = autoButton,
		status = status,
		fields = fields,
		overview = overview,
		overviewHint = overviewHint,
		sectionLayer = sectionLayer,
		waveformLayer = waveformLayer,
		tickLayer = tickLayer,
		markerLayer = markerLayer,
		playhead = playhead,
		beatLight = beatLight,
		beatLabel = beatLabel,
		readout = readout,
		exportBox = exportBox,
	}
end

function TaggerUI.getField(ui: UI, name: string): string
	local text = ui.fields[name].Text
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

function TaggerUI.setField(ui: UI, name: string, value: string)
	ui.fields[name].Text = value
end

-- Grey hint text shown while a field is empty.
function TaggerUI.setFieldHint(ui: UI, name: string, hint: string)
	ui.fields[name].PlaceholderText = hint
end

function TaggerUI.setStatus(ui: UI, text: string, isError: boolean)
	ui.status.Text = text
	ui.status.TextColor3 = if isError then COLORS.error else COLORS.dim
end

function TaggerUI.setReadout(ui: UI, text: string)
	ui.readout.Text = text
end

function TaggerUI.setExport(ui: UI, text: string)
	ui.exportBox.Text = text
end

-- `flash` runs from 1 (on the beat) down to 0. Downbeats flash white, other beats in the accent colour.
function TaggerUI.setBeatLight(ui: UI, flash: number, isDownbeat: boolean, label: string)
	local color = if isDownbeat then COLORS.downbeat else COLORS.accent
	ui.beatLight.BackgroundColor3 = COLORS.panel:Lerp(color, flash)
	ui.beatLabel.Text = label
	ui.beatLabel.TextColor3 = if isDownbeat and flash > 0.5 then COLORS.background else COLORS.text
end

function TaggerUI.setPlayhead(ui: UI, fraction: number)
	ui.playhead.Visible = true
	ui.overviewHint.Visible = false
	ui.playhead.Position = UDim2.fromScale(math.clamp(fraction, 0, 1), 0)
end

local function clear(layer: Frame)
	for _, child in layer:GetChildren() do
		child:Destroy()
	end
end

-- Bar lines across the whole track; every 8th bar (a 32-beat phrase) is taller.
function TaggerUI.drawGrid(ui: UI, length: number, bpm: number?, origin: number?)
	clear(ui.tickLayer)
	if not bpm or not origin or length <= 0 then
		return
	end
	local barLength = BeatMath.beatLength(bpm) * BeatMath.BEATS_PER_BAR
	local firstBar = math.ceil(-origin / barLength)
	local lastBar = math.floor((length - origin) / barLength)
	local phrasesOnly = lastBar - firstBar > 400
	for bar = firstBar, lastBar do
		local isPhrase = bar % 8 == 0
		if isPhrase or not phrasesOnly then
			local fraction = (origin + bar * barLength) / length
			marker(ui.tickLayer, fraction, COLORS.text, if isPhrase then 0.45 else 0.2, if isPhrase then 0.35 else 0.75)
		end
	end
end

-- Coloured blocks, one per section, each running until the next section starts.
function TaggerUI.drawSections(ui: UI, length: number, sections: { Types.Section }, bpm: number?, firstBeat: number?)
	clear(ui.sectionLayer)
	if not bpm or not firstBeat or length <= 0 then
		return
	end
	for i, section in sections do
		local startTime = BeatMath.beatToTime(section.startBeat, bpm, firstBeat)
		local nextSection = sections[i + 1]
		local endTime = if nextSection then BeatMath.beatToTime(nextSection.startBeat, bpm, firstBeat) else length

		local block = Instance.new("Frame")
		block.BorderSizePixel = 0
		block.BackgroundColor3 = SECTION_COLORS[section.kind]
		block.BackgroundTransparency = 0.25
		block.Position = UDim2.fromScale(startTime / length, 0)
		block.Size = UDim2.fromScale((endTime - startTime) / length, 1)
		block.Parent = ui.sectionLayer

		local label = textLabel(block, section.kind, UDim2.fromScale(1, 0.4), 0)
		label.TextSize = 13
		label.TextTruncate = Enum.TextTruncate.AtEnd
		padding(label, 4, 0)
	end
end

-- The track's real waveform: one column per point, as tall as the loudest sample there.
function TaggerUI.drawWaveform(ui: UI, points: { number })
	clear(ui.waveformLayer)
	local width = 1 / math.max(1, #points)
	for i, peak in points do
		local column = Instance.new("Frame")
		column.BorderSizePixel = 0
		column.BackgroundColor3 = COLORS.text
		column.BackgroundTransparency = 0.55
		column.AnchorPoint = Vector2.new(0, 0.5)
		column.Position = UDim2.fromScale((i - 1) * width, 0.5)
		column.Size = UDim2.fromScale(width, math.clamp(peak, 0.02, 1) * 0.9)
		column.Parent = ui.waveformLayer
	end
end

-- The first downbeat (green) and the cue point (amber).
function TaggerUI.drawMarkers(ui: UI, length: number, firstBeat: number?, cueTime: number?)
	clear(ui.markerLayer)
	if length <= 0 then
		return
	end
	if firstBeat then
		marker(ui.markerLayer, firstBeat / length, COLORS.firstBeat, 1, 0)
	end
	if cueTime then
		marker(ui.markerLayer, cueTime / length, COLORS.cue, 0.7, 0)
	end
end

return TaggerUI
