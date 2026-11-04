--!strict
-- The picture on a big LED wall (a part with the "wall" light role, like Ibiza's stage wall),
-- made on this client: a row of level bars that pump on every kick, climb through a build and
-- burst on the drop, over a glow in the location's colours. LightShow drives it with the beat.

local LedWall = {}

local BARS = 16
local PIXELS_PER_STUD = 8 -- a coarse picture, like a real LED wall from the dance floor

export type Wall = {
	gui: SurfaceGui,
	glow: Frame,
	bars: { Frame },
}

-- What the wall shows at one moment.
export type Moment = {
	beat: number, -- the beat in the main track
	kick: number, -- 1 on a beat, falling to 0 before the next
	intensity: number, -- the section's level, 0..1
	drop: boolean,
	colours: { Color3 }, -- the location's palette
	blast: number, -- the white flash on a drop, 0..1
}

function LedWall.build(part: BasePart): Wall
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LedWall"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.ClipsDescendants = true

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BorderSizePixel = 0
	glow.BackgroundColor3 = Color3.new(0, 0, 0)
	glow.Parent = gui

	local bars: { Frame } = {}
	for index = 1, BARS do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. index
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale((index - 1) / BARS + 0.006, 1)
		bar.Size = UDim2.fromScale(1 / BARS - 0.012, 0.1)
		bar.BorderSizePixel = 0
		bar.Parent = gui
		table.insert(bars, bar)
	end
	gui.Parent = part
	return { gui = gui, glow = glow, bars = bars }
end

-- Draws one moment of the show.
function LedWall.draw(wall: Wall, frame: Moment)
	local colours = frame.colours
	local white = Color3.new(1, 1, 1)
	local base = colours[1]
	wall.glow.BackgroundColor3 =
		Color3.new(0, 0, 0):Lerp(base, 0.15 + 0.25 * frame.intensity):Lerp(white, frame.blast * 0.7)
	for index, bar in wall.bars do
		-- Each bar moves at its own pace, the middle ones higher, all of them on the kick.
		local wave = 0.5 + 0.5 * math.sin(index * 1.7 + frame.beat * math.pi / 2)
		local middle = 1 - math.abs(index - (#wall.bars + 1) / 2) / (#wall.bars / 2)
		local level = 0.08
			+ frame.intensity * (0.25 + 0.45 * wave * (0.5 + 0.5 * middle))
			+ 0.3 * frame.kick * frame.intensity
		if frame.drop then
			level = math.min(1, level + 0.2)
		end
		bar.Size = UDim2.fromScale(bar.Size.X.Scale, math.clamp(level, 0.03, 1))
		local colour = colours[(index + math.floor(frame.beat / 4)) % #colours + 1]
		bar.BackgroundColor3 = colour:Lerp(white, frame.blast * 0.8 + (if frame.drop then 0.25 * frame.kick else 0))
	end
end

return LedWall
